FROM node

MAINTAINER Johannes Unterstein <junterstein@mesosphere.io>

RUN npm install --save express http-proxy

ADD app.js /app.js

CMD ["node", "/app.js"]
