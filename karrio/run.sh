#!/usr/bin/env bashio
# shellcheck shell=bash
# Read add-on options from /data/options.json, set up the data directory,
# and hand off to the upstream karrio entrypoint as the karrio user.
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

# Persist karrio's working files (SQLite app DB, huey queue, static files)
# under /data so they survive add-on restarts and are included in Home
# Assistant snapshots. The karrio user (created by the upstream image)
# needs to own them.
mkdir -p "${WORK_DIR}" "${LOG_DIR}" "${STATIC_ROOT_DIR}"
chown -R karrio:karrio /data "${WORK_DIR}"

# Run karrio with SQLite + in-process worker: with neither DATABASE_HOST nor
# REDIS_HOST set, karrio falls back to SQLite for both the app DB and the
# huey task queue, and DETACHED_WORKER=False keeps the worker inside
# gunicorn. Single process, no redis, no postgres.
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

bashio::log.info "Starting karrio (SQLite, in-process worker) on :${KARRIO_HTTP_PORT}..."

# The upstream entrypoint and gunicorn-cfg.py live in /karrio/app and expect
# to be invoked from there. Hand off via 'su -p' (preserve-environment) so
# karrio runs as the unprivileged karrio user the upstream image created
# while keeping the env vars we just exported.
cd /karrio/app
exec su -p -s /bin/bash karrio -c '/karrio/venv/bin/dumb-init -- ./entrypoint'
