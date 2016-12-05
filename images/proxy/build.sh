#!/bin/bash

cd $(dirname $0)

docker build --tag neo4j/neo4j-dcos-proxy:latest .
