#!/bin/bash

cd $(dirname $0)

./neo4j/build.sh
./proxy/build.sh
