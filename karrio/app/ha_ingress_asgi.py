"""ASGI wrapper that honours Home Assistant ingress headers.

The HA Supervisor reverse-proxies the add-on under a per-session URL
prefix and tells the backend about it via the X-Ingress-Path header.
Django reads ASGI's `root_path` to build absolute URLs (Karrio's HOST,
ADMIN, GRAPHQL, OPENAPI fields among them), so we copy the header into
the scope before Karrio's ASGI app sees the request.

We also 302 the root path to /admin/ so the sidebar/Open-Web-UI lands on
something useful instead of karrio's bare JSON capabilities document.
"""
from karrio.server.asgi import application as _karrio_app


async def application(scope, receive, send):
    if scope["type"] in ("http", "websocket"):
        ingress_path = ""
        new_headers = []
        for name, value in scope.get("headers") or ():
            # Sandboxed iframes (HA ingress) send Origin: null. Django 4+
            # rejects "null" in CSRF_TRUSTED_ORIGINS (no scheme), so drop
            # the header here and let Django fall back to Referer, which
            # HA sets to the real ingress URL.
            if name == b"origin" and value == b"null":
                continue
            if name == b"x-ingress-path" and value:
                ingress_path = value.decode("latin-1").rstrip("/")
            new_headers.append((name, value))
        scope = {**scope, "headers": new_headers, "root_path": ingress_path}

        # Rewrite the root path to /login/ in-place so the sidebar lands
        # on karrio's login UI. A 302 redirect would be cleaner, but HA
        # ingress lands users on https://<ha>/<slug> (no trailing slash)
        # and a relative redirect resolves against the parent directory
        # (i.e. https://<ha>/login/), bypassing ingress entirely.
        #
        # karrio overrides Django's LOGIN_URL to "/login/" (not the
        # Django-default /admin/login/), so we route there directly;
        # once logged in, /login/ redirects staff users on to /admin/.
        if scope["type"] == "http" and scope["path"] in ("", "/"):
            scope = {
                **scope,
                "path": "/login/",
                "raw_path": (scope.get("root_path", "").encode("latin-1") + b"/login/"),
            }

    await _karrio_app(scope, receive, send)
