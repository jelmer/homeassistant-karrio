ARG BUILD_FROM=node:22-slim
ARG KARRIO_VERSION=2026.1.32
ARG BASHIO_VERSION=0.18.1

# ---------------------------------------------------------------------------
# Stage 1: build the karrio dashboard (Next.js standalone output) from
# source so it works on both amd64 and arm64. Follows the upstream
# docker/dashboard/Dockerfile recipe (turbo prune -> npm ci -> next build).
# ---------------------------------------------------------------------------
FROM node:22-slim AS dashboard-build
ARG KARRIO_VERSION

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g turbo@^2

WORKDIR /src
RUN git clone --depth 1 --branch "${KARRIO_VERSION}" https://github.com/karrioapi/karrio.git . \
    || git clone --depth 1 https://github.com/karrioapi/karrio.git .

# Prune the monorepo to just the dashboard and its workspace deps.
RUN turbo prune @karrio/dashboard --docker

WORKDIR /src/out

# Install deps from the pruned lockfile.
RUN --mount=type=cache,target=/root/.npm \
    cd json && npm ci --include=dev

# Bring in the pruned source and build.
RUN cp -a full/. json/
WORKDIR /src/out/json

ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_PUBLIC_DASHBOARD_VERSION=${KARRIO_VERSION}
# Build with an empty public URL so the browser makes relative-URL API
# calls back to the dashboard origin; our Node proxy then forwards
# karrio-owned paths (/v1/, /graphql, /api/auth, /static/) to the
# sibling karrio addon at runtime. This keeps everything under the
# dashboard's ingress URL.
ENV NEXT_PUBLIC_KARRIO_PUBLIC_URL=""
RUN npm run build -w apps/dashboard

# ---------------------------------------------------------------------------
# Stage 2: runtime image.
# ---------------------------------------------------------------------------
# hadolint ignore=DL3006
FROM ${BUILD_FROM}
ARG BASHIO_VERSION
ARG KARRIO_VERSION

ENV \
    LANG="C.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    NEXT_PUBLIC_DASHBOARD_VERSION=${KARRIO_VERSION}

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        tini \
        tzdata \
    && curl -fsSL "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - -C /tmp \
    && mv "/tmp/bashio-${BASHIO_VERSION}/lib" /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && rm -rf "/tmp/bashio-${BASHIO_VERSION}" /var/lib/apt/lists/*

WORKDIR /app

# Copy the Next.js standalone output: a self-contained server + traced
# node_modules, the static chunks, and the public assets.
COPY --from=dashboard-build /src/out/json/apps/dashboard/.next/standalone /app/
COPY --from=dashboard-build /src/out/json/apps/dashboard/.next/static /app/apps/dashboard/.next/static
COPY --from=dashboard-build /src/out/json/apps/dashboard/public /app/apps/dashboard/public

# Our HA-ingress shim and run script.
COPY ha_ingress_server.js /app/ha_ingress_server.js
COPY run.sh /run.sh
RUN chmod +x /run.sh

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

EXPOSE 3002

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/run.sh"]
