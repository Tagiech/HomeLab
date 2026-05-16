ARG VERSION
FROM docker.n8n.io/n8nio/n8n:${VERSION}

USER root

ARG UID
ARG GID

RUN deluser node || true; \
    addgroup -g ${GID} node;\
    adduser -D -u ${UID} -G node node;\
    mkdir -p /home/node && chown -R node:node /home/node;

USER node