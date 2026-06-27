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

if bashio::var.is_empty "${secret_key}"; then
    bashio::exit.nok "Option 'secret_key' is required. Set it to a long random string in the addon configuration."
fi

# Karrio writes the SQLite app DB, huey queue, logs, and collected static
# files under /data; Home Assistant persists this directory across
# restarts and includes it in snapshots.
mkdir -p /data/karrio "${LOG_DIR}" "${STATIC_ROOT_DIR}"
chown -R karrio:karrio /data/karrio /karrio/plugins

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
export KARRIO_HTTP_PORT=5002
# WORK_DIR is where karrio puts db.sqlite3; the upstream code joins it with
# DATABASE_NAME. Override it to live under /data so the DB persists, even
# though the entrypoint scripts themselves live in /karrio/app.
export WORK_DIR=/data/karrio

bashio::log.info "Starting karrio (SQLite, in-process worker) on :${KARRIO_HTTP_PORT}..."
cd /karrio/app
exec su -p -s /bin/bash karrio -c '/karrio/venv/bin/dumb-init -- ./entrypoint'
