FROM neo4j:3.3.3-enterprise

RUN apk add -U bind-tools && rm -f /var/cache/apk/*

COPY init-dcos-neo4j.sh /init-dcos-neo4j.sh

ENTRYPOINT ["/init-dcos-neo4j.sh"]
