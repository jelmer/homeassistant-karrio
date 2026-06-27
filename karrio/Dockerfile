ARG BUILD_FROM=python:3.12-slim
ARG KARRIO_VERSION=2026.1.32
ARG BASHIO_VERSION=0.18.1

# ---------------------------------------------------------------------------
# Stage 1: compile the karrio venv. Builds on amd64 and arm64 since
# python:3.12-slim is multi-arch and the karrio packages on PyPI are pure
# Python.
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS compile
ARG KARRIO_VERSION

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libc6-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /karrio/venv
ENV PATH="/karrio/venv/bin:$PATH"

# Install karrio + all open-source carrier plugins from PyPI. The list
# matches modules/core/karrio/server/conf/__init__.py and upstream's
# requirements.txt; pinning to one VERSION keeps everything in lockstep.
# pyzint (transitive dep) ships as sdist with no manylinux wheel and has
# call-site type mismatches that gcc 14 (Debian trixie) treats as hard
# errors. Demote them to warnings, matching the gcc 12 behaviour the
# upstream karrio/server image is built with.
ENV CFLAGS="-Wno-incompatible-pointer-types"

# hadolint ignore=DL3013
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip \
    && pip install dumb-init "gunicorn[gevent]" uvicorn \
        "karrio==${KARRIO_VERSION}" \
        "karrio-server==${KARRIO_VERSION}" \
        "karrio-server-core==${KARRIO_VERSION}" \
        "karrio-server-data==${KARRIO_VERSION}" \
        "karrio-server-documents==${KARRIO_VERSION}" \
        "karrio-server-events==${KARRIO_VERSION}" \
        "karrio-server-graph==${KARRIO_VERSION}" \
        "karrio-server-manager==${KARRIO_VERSION}" \
        "karrio-server-orders==${KARRIO_VERSION}" \
        "karrio-server-pricing==${KARRIO_VERSION}" \
        "karrio-server-proxy==${KARRIO_VERSION}" \
        "karrio-australiapost==${KARRIO_VERSION}" \
        "karrio-canadapost==${KARRIO_VERSION}" \
        "karrio-chronopost==${KARRIO_VERSION}" \
        "karrio-dhl-express==${KARRIO_VERSION}" \
        "karrio-dhl-parcel-de==${KARRIO_VERSION}" \
        "karrio-dhl-poland==${KARRIO_VERSION}" \
        "karrio-dhl-universal==${KARRIO_VERSION}" \
        "karrio-dpd==${KARRIO_VERSION}" \
        "karrio-dpd-meta==${KARRIO_VERSION}" \
        "karrio-easypost==${KARRIO_VERSION}" \
        "karrio-easyship==${KARRIO_VERSION}" \
        "karrio-eshipper==${KARRIO_VERSION}" \
        "karrio-fedex==${KARRIO_VERSION}" \
        "karrio-freightcom==${KARRIO_VERSION}" \
        "karrio-generic==${KARRIO_VERSION}" \
        "karrio-gls==${KARRIO_VERSION}" \
        "karrio-hermes==${KARRIO_VERSION}" \
        "karrio-landmark==${KARRIO_VERSION}" \
        "karrio-laposte==${KARRIO_VERSION}" \
        "karrio-purolator==${KARRIO_VERSION}" \
        "karrio-sapient==${KARRIO_VERSION}" \
        "karrio-seko==${KARRIO_VERSION}" \
        "karrio-sendle==${KARRIO_VERSION}" \
        "karrio-smartkargo==${KARRIO_VERSION}" \
        "karrio-spring==${KARRIO_VERSION}" \
        "karrio-teleship==${KARRIO_VERSION}" \
        "karrio-ups==${KARRIO_VERSION}" \
        "karrio-usps==${KARRIO_VERSION}" \
        "karrio-usps-international==${KARRIO_VERSION}"

# ---------------------------------------------------------------------------
# Stage 2: runtime image. Slim python + libpango (karrio uses it for label
# rendering via WeasyPrint) + bashio for /data/options.json parsing.
# ---------------------------------------------------------------------------
# hadolint ignore=DL3006
FROM ${BUILD_FROM}
ARG BASHIO_VERSION

ENV \
    LANG="C.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    PATH="/karrio/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    WORK_DIR=/karrio/app \
    LOG_DIR=/data/karrio/log \
    WORKER_DB_DIR=/data/karrio \
    STATIC_ROOT_DIR=/data/karrio/static \
    KARRIO_PLUGINS=/karrio/plugins

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        libpango-1.0-0 \
        libpangoft2-1.0-0 \
        passwd \
        tini \
        tzdata \
    && curl -fsSL "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - -C /tmp \
    && mv "/tmp/bashio-${BASHIO_VERSION}/lib" /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && rm -rf "/tmp/bashio-${BASHIO_VERSION}" /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /karrio --shell /bin/bash karrio \
    && mkdir -p "${WORK_DIR}" "${KARRIO_PLUGINS}"

COPY --from=compile --chown=karrio:karrio /karrio/venv /karrio/venv
COPY --chown=karrio:karrio app/ ${WORK_DIR}/
COPY run.sh /run.sh
RUN chmod +x /run.sh "${WORK_DIR}/entrypoint" "${WORK_DIR}/worker"

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
