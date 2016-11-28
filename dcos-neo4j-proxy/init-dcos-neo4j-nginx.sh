#!/bin/bash -eu

path="/etc/nginx/conf.d/default.conf"
backup="/etc/nginx/conf.d/default.conf_backup"
url="${DCOS_NEO4J_DNS_ENTRY:-core-neo4j.marathon.containerip.dcos.thisdcos.directory}"
user="${DCOS_NEO4J_USER:-}"
pass="${DCOS_NEO4J_PASS:-}"
if [ -n $user ] && [ -n $pass ]; then
	auth="-u $user:$pass"
else
	auth=""
fi

# make backup of configuration file if no one is present
if [ ! -e "$backup" ]; then
	cp $path $backup
fi

# try
{
	# find master and update nginx
	response=`curl -s -k $auth -XPOST -H content-type:application/json -H accept:application/json https://$url:7473/db/data/transaction/commit -d'{"statements":[{"statement":"CALL dbms.cluster.routing.getServers()"}]}' | jq '.results[].data[].row[]'`
	leader=`echo $response | jq -r '(.server[] | select(.role | contains("WRITE"))) | .addresses[0]'`
	if [ ! -z $leader ]; then
		# adapt proxy configuration to point only to master
		echo `cat $backup | sed 's/http:.*$/http:\/\/$leader:7474\//g'`
		cat $backup | sed 's/http:.*$/http:\/\/$leader:7474\//g' > $path
		cat $path | sed 's/https:.*$/https:\/\/$leader:7473\//g' >> $path
		service nginx reload
	fi
} || {
	# restore backup if update fails
	mv $backup $path
	service nginx reload
}
