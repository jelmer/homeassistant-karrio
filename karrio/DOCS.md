# Karrio add-on

Runs [Karrio](https://karrio.io) — the open-source shipping API platform —
as a Home Assistant add-on. This is a minimal, single-process deployment
backed by SQLite: no PostgreSQL, no Redis, no separate worker.

## How it works

The add-on is a thin wrapper around the official `karrio/server` Docker
image. It runs a single gunicorn process that serves the REST/GraphQL API
on port 5002 and runs the background worker (huey) in-process. Data is
stored in a SQLite file under `/data/karrio/db.sqlite3`, which is persisted
across restarts and included in Home Assistant snapshots.

For higher-throughput or production deployments, run Karrio with its
upstream `docker-compose.yml` against PostgreSQL and Redis instead — this
add-on is aimed at hobbyist and small-team self-hosting.

## First start

1. Set `secret_key` to a long random string (32+ characters).
2. Optionally change `admin_email` and `admin_password` (defaults are
   `admin@example.com` / `demo`).
3. Start the add-on.
4. Open `http://homeassistant.local:5002/` to reach the Karrio API and
   built-in admin/dashboard.

The first start runs Django migrations and seeds the admin user; this
takes 30-60 seconds. Subsequent starts are fast.

## Configuration options

### `secret_key` (required)

Django secret key used to sign sessions and tokens. At least 32 random
characters. Do not change this once data has been written — existing
sessions and signed values will be invalidated.

### `admin_email` / `admin_password`

Credentials for the initial superuser, created on first start if no users
exist yet. Change `admin_password` from the default before exposing the
add-on to anything you don't trust.

### `allow_signup`

If `true`, users can sign up via the web UI. Default `false`.

### `enable_all_plugins`

If `true` (default), all bundled carrier plugins are enabled.

### `workers`

Number of gunicorn worker processes (default `2`).

### `background_workers`

Number of huey background-task threads (default `2`).

## Data and backups

Everything Karrio writes lives under `/data/karrio`:

- `db.sqlite3` — the application database
- `tasks.sqlite3` — the huey task queue
- `static/` — collected static files
- `log/` — application logs

Home Assistant snapshots include `/data`, so back-ups cover all Karrio
state out of the box.

## Troubleshooting

- **"Option 'secret_key' is required"**: set `secret_key` in the add-on
  configuration to a long random string before starting.
- **Cannot log in**: the default credentials are `admin@example.com` /
  `demo`. To reset, stop the add-on, delete `/data/karrio/db.sqlite3`,
  and restart — a fresh DB is created with the admin user from your
  current options.
- **Slow first start**: expected; the initial Django migration set takes
  30-60 seconds on small hardware.
