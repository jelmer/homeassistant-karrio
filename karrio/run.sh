#!/usr/bin/env bashio
# shellcheck shell=bash
# Read add-on options from /data/options.json, prep the data directory,
# then exec the karrio entrypoint as the karrio user.
set -e

declare secret_key admin_email admin_password
declare allow_signup enable_all_plugins
declare workers background_workers

secret_key=$(bashio::config 'secret_key')
admin_email=$(bashio::config 'admin_email')
admin_password=$(bashio::config 'admin_password')
allow_signup=$(bashio::config 'allow_signup')
enable_all_plugins=$(bashio::config 'enable_all_plugins')
workers=$(bashio::config 'workers')
background_workers=$(bashio::config 'background_workers')

# Fall back to a generated secret_key when the user hasn't set one. We
# persist a copy under /data (survives restarts even if Supervisor write-
# back fails) AND push it back into the addon's options via the
# Supervisor API, so the value shows up in the Configuration tab where
# the user can see, copy, or change it. Rotating the key invalidates
# existing Django sessions and signed tokens.
if bashio::var.is_empty "${secret_key}"; then
    if [ ! -s /data/.secret_key ]; then
        bashio::log.info "Generating a new secret_key..."
        python3 -c 'import secrets; print(secrets.token_urlsafe(48))' > /data/.secret_key
        chmod 600 /data/.secret_key
    fi
    secret_key=$(cat /data/.secret_key)

    # Write it back into the addon's options so it appears in the
    # Configuration UI. bashio::app.option merges (read-modify-write)
    # rather than replacing the whole options dict, so we don't drop
    # the other required options.
    if bashio::var.has_value "${SUPERVISOR_TOKEN:-}"; then
        if bashio::app.option 'secret_key' "${secret_key}"; then
            bashio::log.info "Stored generated secret_key in addon options."
        else
            bashio::log.warning "Could not write secret_key back to Supervisor; the value is in /data/.secret_key."
        fi
    fi
fi

# Karrio writes the SQLite app DB, huey queue, logs, and collected static
# files under /data; Home Assistant persists this directory across
# restarts and includes it in snapshots.
mkdir -p /data/karrio "${LOG_DIR}" "${STATIC_ROOT_DIR}" /data/karrio/cache
chown -R karrio:karrio /data/karrio /karrio/plugins

# Fontconfig spams "No writable cache directories" when there's no
# XDG_CACHE_HOME and /karrio is read-only-ish. Point it at /data.
export XDG_CACHE_HOME=/data/karrio/cache
export FONTCONFIG_PATH=/etc/fonts

# With neither DATABASE_HOST nor REDIS_HOST set, karrio uses SQLite for
# both the application database and the huey task queue. DETACHED_WORKER
# keeps the worker inside gunicorn.
export SECRET_KEY="${secret_key}"
export ADMIN_EMAIL="${admin_email}"
export ADMIN_PASSWORD="${admin_password}"
export ALLOW_SIGNUP="${allow_signup}"
export ENABLE_ALL_PLUGINS_BY_DEFAULT="${enable_all_plugins}"
export KARRIO_WORKERS="${workers}"
export BACKGROUND_WORKERS="${background_workers}"
export DETACHED_WORKER=False
export DEBUG_MODE=False
export USE_HTTPS=False
export ALLOWED_HOSTS="*"
# Force the SQLite backend. Karrio's settings only pick SQLite if
# DATABASE_NAME contains "sqlite3" OR DATABASE_ENGINE is set explicitly;
# otherwise it falls back to PostgreSQL on localhost. Set both to be safe.
export DATABASE_ENGINE=sqlite3
export DATABASE_NAME=db.sqlite3
# Trust any origin reaching us. The ingress reverse proxy enforces
# its own auth before requests get here, and the ASGI wrapper strips
# Origin: null (which sandboxed iframes send and which Django 4+
# can't be configured to accept) so Django falls back to the Referer
# header HA sets correctly.
export CSRF_TRUSTED_ORIGINS="http://*,https://*"
export KARRIO_HTTP_PORT=5002
# WORK_DIR is where karrio puts db.sqlite3; the upstream code joins it with
# DATABASE_NAME. Override it to live under /data so the DB persists, even
# though the entrypoint scripts themselves live in /karrio/app.
export WORK_DIR=/data/karrio

bashio::log.info "Starting karrio (SQLite, in-process worker) on :${KARRIO_HTTP_PORT}..."
cd /karrio/app
exec su -p -s /bin/bash karrio -c '/karrio/venv/bin/dumb-init -- ./entrypoint'
