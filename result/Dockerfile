FROM node:24-slim@sha256:2fe369e969550cde8e867afc3fe370b260140cab4a23d467074295b42163d553 AS base

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app
COPY package*.json ./

FROM base AS dev

RUN npm ci && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules && \
    npm install -g nodemon

COPY --chown=node:node . .

ENV PORT=8080

EXPOSE 8080

USER node

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["nodemon", "--inspect=0.0.0.0:9229", "server.js"]

FROM base AS dependencies

RUN npm ci --omit=dev && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules

FROM gcr.io/distroless/nodejs24-debian13:nonroot@sha256:bb6b03d81066993293a10feda7250e8e1cc034035fe9b61cfceededa7c8bf04d AS final

WORKDIR /usr/local/app

COPY --from=dependencies /node_modules /node_modules
COPY --chown=nonroot:nonroot . .

ENV PORT=8080

EXPOSE 8080

CMD ["server.js"]
