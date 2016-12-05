# Neo4j Causal Cluster running on top of DC/OS
## Overview
Neo4j’s Causal Clustering provides two main features:

**Safety**: Core servers provide a fault tolerant platform for transaction processing which will remain available while a simple majority of those Core servers are functioning.

**Scale**: Read replicas provide a massively scalable platform for graph queries that enables very large graph workloads to be executed in a widely distributed topology.
Together, this allows the end-user system to be fully functional and both read and write to the database in the event of multiple hardware and network failures.

In remainder of this section we will provide an overview of how causal clustering works in production, covering both operational and application aspects.

From an operational point of view, it is useful to view the cluster as being composed from its two different roles: Core and Read replica.

![alt text](http://neo4j.com/docs/operations-manual/beta/images/causal-clustering.png "causal clustering")

The two roles are foundational in any production deployment but are managed at different scales from one another and undertake different roles in managing the fault tolerance and scalability of the overall cluster.

### Core servers
Core servers' main responsibility is to safeguard data. The Core servers do so by replicating all transactions using the Raft protocol. Raft ensures that the data is safely durable before confirming transaction commit to the end user application. In practice this means once a majority of Core servers in a cluster `(N/2+1)` have accepted the transaction, it is safe to acknowledge the commit to the end user application.

### Read replicas
Read replicas' main responsibility is to scale out graph workloads (Cypher queries, procedures, and so on). Read replicas act like caches for the data that the Core servers safeguard, but they are not simple key-value caches. In fact Read replicas are fully-fledged Neo4j databases capable of fulfilling arbitrary (read-only) graph queries and procedures.

### Go deeper
Please visit the [Neo4j Causal Clustering documentation](http://neo4j.com/docs/operations-manual/beta/clustering-architecture/causal-cluster) to get more information about Neo4j Causal Clustering.

## Install packages on your DC/OS cluster
### Core nodes
Go to the universe and install the `neo4j` or do `dcos package install neo4j`. The default configuration for one core instance is:

```
auth-username=neo4j
auth-password=dcos
cpus(shares)=2
mem=8000
disk=8000
instances=3
expected-cluster-size=3
network-name=dcos
```

### Read replica nodes
Go to the universe and install the `neo4j-replica` or do `dcos package install neo4j-replica`. The default configuration for one read replica instance is:

```
auth-username=neo4j
auth-password=dcos
cpus(shares)=2
mem=4000
disk=8000
instances=2
network-name=dcos
```

### Public proxy
Go to the universe and install the `neo4j-proxy` or do `dcos package install neo4j-proxy`. The default configuration for one read replica instance is:

```
auth-username=neo4j
auth-password=dcos
```


## Persistence
Note: You are using local persistent volumes. The big advantage of using local persistent volume vs ephemeral volumes or remote volumes is:


- If a Neo4j cluster node failes, a fresh instance will be restarted on the same machine again and the replacement instance becomes the same data like the failed one.
- Therefore Neo4j can decide if it wants to reuse the data or if the data will be invalidated.
- Neo4j clustering has build in replication, therefore there is no need for an remote volume.
- You don`t have remote writes, because this volume is on your local disk.

## Docker images
### Base image
This implementation based on the [official docker-neo4j image](https://github.com/neo4j/docker-neo4j/tree/master/src/3.1) and has only few adaptions to add service discovery within the DC/OS cluster using DNS.

### Networking
The Neo4j is running inside an overlay network, where each container will receive an own IP address and exposes all ports within this overlay network. This overlay network and the resulting IP addresses are only available within the DC/OS cluster

### Adaptions
#### Neo4j cluster image
The main part of the adaptions to run the official docker-neo4j image on top of DC/OS are related to service discovery, see the [https://github.com/neo4j-contrib/neo4j-dcos/blob/master/images/neo4j/init-dcos-neo4j.sh](entrypoint of the neo4j cluster image).

#### Neo4j public proxy image
To access your neo4j cluster from outside the DC/OC cluster, you need to install a proxy server on a public DC/OS agent server. This can be done via `dcos package install neo4j-proxy`. This proxy server is a small nodeJS server polling once in while the Neo4j cluster asking about the current topology and adapting the proxy route to **talk to Neo4j current master node**.

### Configuration
To run the actual Neo4j cluster, one image is used: `neo4j/neo4j-dcos:1.0.0-3.1-RC1`
Both, `core` and `read replica` installations use this images and only have separate environment variable configuration.

## Release
To build a release, do for example:

```
./images/build.sh
./images/push.sh neo4j-dcos 1.0.0-3.1-RC1
./images/push.sh neo4j-dcos-proxy 1.0.0
```