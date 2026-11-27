FROM node:22-alpine

WORKDIR /service
COPY package.json ./
COPY baileys-lid-pn-decrypt.patch /tmp/baileys-lid-pn-decrypt.patch
RUN apk add --no-cache git && npm install --omit=dev && \
    cd /service/node_modules/@whiskeysockets/baileys && git apply /tmp/baileys-lid-pn-decrypt.patch
COPY server.js ./

ENV BAILEYS_DATA_DIR=/data
EXPOSE 3001

CMD ["node", "server.js"]
