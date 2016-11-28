#!/bin/bash -eu

path="/etc/nginx/conf.d/default.conf"
backup="/etc/nginx/default.conf_backup"
url="${DCOS_NEO4J_DNS_ENTRY:-core-neo4j.marathon.containerip.dcos.thisdcos.directory}"
user="${DCOS_NEO4J_USER:-}"
pass="${DCOS_NEO4J_PASS:-}"
if [ -n $user ] && [ -n $pass ]; then
	auth="-u $user:$pass"
else
	auth=""
fi

# make backup of configuration file if no one is present
cp -n $path $backup

# try
{
	# find master and update nginx
        response=`curl -s -k $auth -XPOST -H content-type:application/json -H accept:application/json https://$url:7473/db/data/transaction/commit -d'{"statements":[{"statement":"CALL dbms.cluster.overview()"}]}'`
        leader=`echo $response | jq '.results[].data[].row | select(.[2] | contains("LEADER")) | .[1][]'`
		leader_clean=`echo $leader | sed 's/"//g'`
        if [ -z "$leader_clean" ]; then
                echo "no leader found for logging"
        else
                # adapt proxy configuration to point only to master
                mv $backup $path
                http=`echo $leader | jq -r 'select(. | contains("http:"))'`
                https=`echo $leader | jq -r 'select(. | contains("https:"))'`
                sed -i "s%http:.*$%$http/%g" $path
                sed -i "s%https:.*$%$https/%g" $path
                service nginx reload
        fi
} || {
	# restore backup if update fails
	mv $backup $path
	service nginx reload
}