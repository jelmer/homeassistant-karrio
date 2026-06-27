# Karrio Home Assistant Add-on

Run [Karrio](https://karrio.io) — the open-source shipping API platform —
as a [Home Assistant](https://www.home-assistant.io/) add-on.

This is a minimal, single-process build: it wraps the official
`karrio/server` Docker image and runs Karrio with SQLite as the database
and an in-process background worker. No PostgreSQL or Redis required.

## Installation

1. In Home Assistant, go to **Settings -> Add-ons -> Add-on Store**.
2. Click the three-dot menu in the top right and choose **Repositories**.
3. Add `https://github.com/jelmer/homeassistant-karrio` and click **Add**.
4. The **Karrio** add-on will appear in the store. Install it.
5. Open the add-on's **Configuration** tab, set `secret_key` to a long
   random string, optionally change `admin_password`, and start the add-on.
6. Open `http://homeassistant.local:5002/` to reach Karrio.

See [`karrio/DOCS.md`](karrio/DOCS.md) for the full list of configuration
options.

## Scope

This add-on is intended for hobby use. For higher-throughput deployments
use Karrio's upstream `docker-compose.yml` against PostgreSQL and Redis.

## License

Add-on packaging is MIT-licensed. Karrio itself is dual-licensed — see the
[Karrio repository](https://github.com/karrioapi/karrio) for details.
