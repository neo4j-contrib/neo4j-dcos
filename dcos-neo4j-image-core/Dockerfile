FROM neo4j/neo4j-experimental:3.1.0-M13-beta3-enterprise

MAINTAINER Johannes Unterstein <junterstein@mesosphere.io>

RUN apk add -U bind-tools && rm -f /var/cache/apk/*

COPY init-dcos-neo4j.sh /init-dcos-neo4j.sh

ENTRYPOINT ["/init-dcos-neo4j.sh"]
