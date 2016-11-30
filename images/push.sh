#!/bin/bash

cd $(dirname $0)

docker push unterstein/dcos-neo4j:latest
docker push unterstein/dcos-neo4j-proxy:latest
