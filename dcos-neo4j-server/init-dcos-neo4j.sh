#!/bin/bash -eu

# set heap based on marathon configuration
mem=`echo $MARATHON_APP_RESOURCE_MEM | sed -e 's/.0//g'`
export NEO4J_dbms_memory_heap_maxSize=$mem

# calc public ip
ip=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`

# exporting port stuff
export NEO4J_causalClustering_discoveryAdvertisedAddress=$ip":5000"
export NEO4J_causalClustering_transactionAdvertisedAddress=$ip":6000"
export NEO4J_causalClustering_raftAdvertisedAddress=$ip":7000"

# sleep some time to get dns up
sleep 15

# calculate discovery members
digs=`dig +short core-neo4j.marathon.containerip.dcos.thisdcos.directory`
members=`echo $digs | sed -e "s/$ip //g" -e 's/ /:5000,/g'`":5000"
export NEO4J_causalClustering_initialDiscoveryMembers=$members

# do initial docker-entrypoint.sh
/docker-entrypoint.sh neo4j
