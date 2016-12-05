FROM neo4j/neo4j-experimental:3.1.0-RC1-enterprise

RUN apk add -U bind-tools && rm -f /var/cache/apk/*

COPY init-dcos-neo4j.sh /init-dcos-neo4j.sh

ENTRYPOINT ["/init-dcos-neo4j.sh"]
