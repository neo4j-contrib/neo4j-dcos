#!/bin/bash

cd $(dirname $0)

./dcos-neo4j-server/build.sh
./dcos-neo4j-proxy/build.sh
