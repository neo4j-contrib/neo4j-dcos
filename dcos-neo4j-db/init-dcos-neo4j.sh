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

# set heap based on marathon configuration
mem=`echo $MARATHON_APP_RESOURCE_MEM | sed -e 's/.0//g'`
export NEO4J_dbms_memory_heap_maxSize=$mem

# calc public ip
ip=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

# exporting port stuff
export NEO4J_causalClustering_discoveryAdvertisedAddress=$ip":5000"
export NEO4J_causalClustering_transactionAdvertisedAddress=$ip":6000"
export NEO4J_causalClustering_raftAdvertisedAddress=$ip":7000"
export NEO4J_dbms_advertisedAddress=$ip

# this should be removed when https://github.com/neo4j/docker-neo4j/pull/68 is merged
setting "dbms.connectors.default_advertised_address" "$NEO4J_dbms_advertisedAddress"

# try until DNS is ready
url="${DCOS_NEO4J_DNS_ENTRY:-core-neo4j.marathon.containerip.dcos.thisdcos.directory}"
for i in {1..15}
do
	digs=`dig +short $url`
	if [ -z $digs ]; then
		echo "no DNS record found for $url"
	else
		# calculate discovery members
		members=`echo $digs | sed -e "s/$ip //g" -e 's/ /:5000,/g'`":5000"
		echo "calculated initial discovery members: $members"
		export NEO4J_causalClustering_initialDiscoveryMembers=$members
		break
	fi
   sleep 1
done

# do initial docker-entrypoint.sh
/docker-entrypoint.sh neo4j
