#!/usr/bin/env bashio
# shellcheck shell=bash
set -e

declare karrio_url nextauth_secret

karrio_url=$(bashio::config 'karrio_url')
nextauth_secret=$(bashio::config 'nextauth_secret')

# Default to HA's addon-to-addon hostname for the sibling karrio addon.
# HA names addons <repo-hash>-<slug>; that repo-hash isn't predictable
# from our side, so derive it from our own hostname (which has the
# same prefix) by swapping our slug for karrio's.
if bashio::var.is_empty "${karrio_url}"; then
    own_host=$(hostname)
    sibling_host="${own_host%-dashboard}"
    karrio_url="http://${sibling_host}:5002"
fi

# Auto-generate (and persist + surface) the NextAuth secret if empty.
if bashio::var.is_empty "${nextauth_secret}"; then
    if [ ! -s /data/.nextauth_secret ]; then
        bashio::log.info "Generating a new nextauth_secret..."
        node -e 'console.log(require("crypto").randomBytes(48).toString("base64url"))' > /data/.nextauth_secret
        chmod 600 /data/.nextauth_secret
    fi
    nextauth_secret=$(cat /data/.nextauth_secret)

    if bashio::var.has_value "${SUPERVISOR_TOKEN:-}"; then
        if bashio::app.option 'nextauth_secret' "${nextauth_secret}"; then
            bashio::log.info "Stored generated nextauth_secret in addon options."
        else
            bashio::log.warning "Could not write nextauth_secret back to Supervisor; the value is in /data/.nextauth_secret."
        fi
    fi
fi

export PORT=3002
export HOSTNAME=0.0.0.0
export NODE_ENV=production
export AUTH_TRUST_HOST=true
export NEXTAUTH_SECRET="${nextauth_secret}"
export KARRIO_URL="${karrio_url}"
export NEXT_PUBLIC_KARRIO_PUBLIC_URL="${karrio_url}"

bashio::log.info "Starting Karrio dashboard on :${PORT}, talking to ${KARRIO_URL}..."
cd /app
exec node ha_ingress_server.js
