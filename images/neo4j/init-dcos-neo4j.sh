#!/bin/bash -eu

# this should be removed when https://github.com/neo4j/docker-neo4j/pull/68 is merged
setting() {
    setting="${1}"
    value="${2}"
    file="neo4j.conf"

    if [ -n "${value}" ]; then
        if grep -q -F "${setting}=" conf/"${file}"; then
            sed --in-place "s|.*${setting}=.*|${setting}=${value}|" conf/"${file}"
        else
            echo "${setting}=${value}" >>conf/"${file}"
        fi
    fi
}

extract_app_id() {
    # calculating dns name for service discovery, see https://docs.mesosphere.com/1.8/usage/service-discovery/dns-overview/
    parts=$(echo "$1" | tr "/" " ")

    # join the array together again by `-` as separator
    result=""
    separator=""
    for part in $parts
    do
        result="$part$separator$result"
        separator="-"
    done
    echo "${result}"
}

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


# calc public ip
ip=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

# exporting port stuff
export NEO4J_causalClustering_discoveryAdvertisedAddress=$ip":5000"
export NEO4J_causalClustering_transactionAdvertisedAddress=$ip":6000"
export NEO4J_causalClustering_raftAdvertisedAddress=$ip":7000"
export NEO4J_dbms_advertisedAddress=$ip

# this should be removed when https://github.com/neo4j/docker-neo4j/pull/68 is merged
setting "dbms.connectors.default_advertised_address" "$NEO4J_dbms_advertisedAddress"

# wait 5 seconds for dns to
echo "waiting 5 seconds for dns"
sleep 5

if [ "${NEO4J_dbms_mode:-}" == "CORE" ]; then
    echo "Calculating DNS name of CORE members for core"
    result=$(extract_app_id "${MARATHON_APP_ID}")

    url="$result.marathon.containerip.dcos.thisdcos.directory"
else
    # Calculation for READ_REPLICATE members
    if [ -n "${DCOS_NEO4J_CORE_APP_ID:-}" ]; then
        echo "Calculating DNS name of CORE members for replica"
        url=$(extract_app_id "${DCOS_NEO4J_CORE_APP_ID}")
    else
        echo "Using ENV DCOS_NEO4J_DNS_ENTRY '${DCOS_NEO4J_DNS_ENTRY}' or using default"
        url="${DCOS_NEO4J_DNS_ENTRY:-core-neo4j.marathon.containerip.dcos.thisdcos.directory}"
    fi
fi

# try until DNS is ready
echo "URL using for service discovery: ${url}"
for i in {1..20}
do
	digs=`dig +short $url`
	if [ -z "$digs" ]; then
		echo "no DNS record found for $url"
	else
		# calculate discovery members
		members=`echo $digs | sed -e "s/$ip //g" -e 's/ /:5000,/g'`":5000"
		echo "calculated initial discovery members: ${members}"
		export NEO4J_causalClustering_initialDiscoveryMembers=$members
		break
	fi
   sleep 2
done

# do initial docker-entrypoint.sh
/docker-entrypoint.sh neo4j
