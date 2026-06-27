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
        for name, value in scope.get("headers") or ():
            if name == b"x-ingress-path" and value:
                ingress_path = value.decode("latin-1").rstrip("/")
                scope = {**scope, "root_path": ingress_path}
                break

        # Rewrite the root path to /admin/ in-place. A 302 redirect would
        # be cleaner, but HA ingress lands users on
        # https://<ha>/<slug> (no trailing slash) and a relative redirect
        # resolves against the parent directory (i.e. https://<ha>/admin/),
        # bypassing ingress entirely. Rewriting in the scope avoids that
        # whole class of URL-resolution edge cases.
        if scope["type"] == "http" and scope["path"] in ("", "/"):
            scope = {
                **scope,
                "path": "/admin/",
                "raw_path": (scope.get("root_path", "").encode("latin-1") + b"/admin/"),
            }

    await _karrio_app(scope, receive, send)
