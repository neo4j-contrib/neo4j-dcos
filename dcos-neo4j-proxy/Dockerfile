FROM nginx

MAINTAINER Johannes Unterstein <junterstein@mesosphere.io>

RUN apt-get update && apt-get install -y curl jq cron

ADD nginx-neo4j.crt /etc/nginx/ssl/nginx-neo4j.crt
ADD nginx-neo4j.key /etc/nginx/ssl/nginx-neo4j.key
ADD nginx.conf /etc/nginx/conf.d/default.conf 

ADD init-dcos-neo4j-nginx.sh /init-dcos-neo4j-nginx.sh
ADD nginx.crontab /etc/cron.d/nginx
ADD start.sh /start.sh

CMD ["/start.sh"]
