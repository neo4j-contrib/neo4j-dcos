#!/bin/bash

cd $(dirname $0)

docker build --tag unterstein/dcos-neo4j:latest .
