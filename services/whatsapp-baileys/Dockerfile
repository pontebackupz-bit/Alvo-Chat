FROM node:22-alpine

WORKDIR /service
COPY package.json ./
RUN apk add --no-cache git && npm install --omit=dev
COPY server.js ./

ENV BAILEYS_DATA_DIR=/data
EXPOSE 3001

CMD ["node", "server.js"]
