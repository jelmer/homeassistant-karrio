ARG BUILD_FROM=karrio.docker.scarf.sh/karrio/server:2026.1.32

# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Switch to root so we can install bashio (needed to parse /data/options.json)
# and our run script. The upstream image drops back to the karrio user; we'll
# do the same in run.sh just before exec'ing karrio.
USER root

ENV \
    LANG="C.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    BASHIO_VERSION="0.16.2"

# bashio is a shell helper Home Assistant add-ons use to read /data/options.json
# and emit structured log output. The upstream package is a single tarball.
# hadolint ignore=DL3008,DL3015
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq tini \
    && curl -L -s "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - -C /tmp \
    && mv "/tmp/bashio-${BASHIO_VERSION}/lib" /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && rm -rf "/tmp/bashio-${BASHIO_VERSION}" /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

# Data lives under /data — Home Assistant persists this across restarts and
# includes it in snapshots. Point the SQLite database and karrio's working
# files at it.
ENV WORK_DIR=/data/karrio \
    WORKER_DB_DIR=/data/karrio \
    LOG_DIR=/data/karrio/log \
    STATIC_ROOT_DIR=/data/karrio/static

ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version="${BUILD_VERSION}" \
    maintainer="Jelmer Vernooĳ <jelmer@jelmer.uk>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
