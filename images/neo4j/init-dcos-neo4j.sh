#!/bin/bash -eu

# current workaround for the scenario when the user edits the app configuration via UI
if [ -n "${NEO4J_DBMS_MODE:-}" ]; then
    export NEO4J_dbms_mode=$NEO4J_DBMS_MODE
fi

# current workaround for the scenario when the user edits the app configuration via UI
if [ -n "${NEO4J_CAUSALCLUSTERING_EXPECTEDCORECLUSTERSIZE:-}" ]; then
    export NEO4J_causalClustering_expectedCoreClusterSize=$NEO4J_CAUSALCLUSTERING_EXPECTEDCORECLUSTERSIZE
fi

# current workaround for the scenario when the user edits the app configuration via UI
if [ -n "${NEO4J_DBMS_MEMORY_HEAP_MAXSIZE:-}" ]; then
    export NEO4J_dbms_memory_heap_maxSize=$NEO4J_DBMS_MEMORY_HEAP_MAXSIZE
fi

if [ -n "${NEO4J_dbms_memory_heap_maxSize:-}" ]; then
    # if no heap space was explicitly configured, 
    # set heap based on marathon configuration, convert given double to integer
    mem=`echo $MARATHON_APP_RESOURCE_MEM | sed 's/\..*$//g'`
    # and limit it to 75% of the container memory
    export NEO4J_dbms_memory_heap_maxSize=$(($mem * 3 / 4))"m"
fi


dns_suffix=".${FRAMEWORK_NAME}.autoip.dcos.thisdcos.directory"
own_name="${TASK_NAME}${dns_suffix}"
echo "Own dns name ${own_name}"


# exporting port stuff
export NEO4J_causalClustering_discoveryAdvertisedAddress="${MESOS_CONTAINER_IP}:5000"
export NEO4J_causalClustering_transactionAdvertisedAddress="${MESOS_CONTAINER_IP}:6000"
export NEO4J_causalClustering_raftAdvertisedAddress="${MESOS_CONTAINER_IP}:7000"
export NEO4J_dbms_connector_bolt_advertised__address="${MESOS_CONTAINER_IP}:7687"

echo "sleep some time"
sleep 5

# discover more members
members=""
separator=""
for (( i=0; i<=NEO4J_causalClustering_expectedCoreClusterSize; i++ ))
do
    check_name="neo4j-${i}-node${dns_suffix}"
    if [[ "${own_name}" != "${check_name}" ]]; then
        for inner in {1..20}
        do
            digs=`dig +short $check_name`
            if [ -z "$digs" ]; then
                echo "no DNS record found for $check_name in try $inner"
            else
                if [[ $members != *"${digs}"* ]]; then
                    members="${members}${separator}${digs}:5000"
                    separator=","
                fi
            fi
        done
    fi
done

echo "calculated initial discovery members: ${members}"
export NEO4J_causalClustering_initialDiscoveryMembers=$members

# do initial docker-entrypoint.sh
/docker-entrypoint.sh neo4j
