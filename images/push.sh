#!/bin/bash

cd $(dirname $0)

docker push neo4j/neo4j-dcos:latest
docker push neo4j/neo4j-dcos-proxy:latest

if [ -n "$1" ] && [ -n "$2" ]; then
  if [ "$1" = "neo4j-dcos" ]; then
  	echo "Releaseing neo4j-dcos in version $2"
  	docker tag neo4j/neo4j-dcos:latest neo4j/neo4j-dcos:$2
  	docker push neo4j/neo4j-dcos:$2
  fi
  if [ "$1" = "neo4j-dcos-proxy" ]; then
  	echo "Releaseing neo4j-dcos-proxy in version $2"
  	docker tag neo4j/neo4j-dcos-proxy:latest neo4j/neo4j-dcos-proxy:$2
  	docker push neo4j/neo4j-dcos-proxy:$2
  fi
fi
