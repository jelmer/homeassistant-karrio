"""ASGI wrapper that honours Home Assistant ingress headers.

The HA Supervisor reverse-proxies the add-on under a per-session URL
prefix and tells the backend about it via the X-Ingress-Path header.
Django reads ASGI's `root_path` to build absolute URLs (Karrio's HOST,
ADMIN, GRAPHQL, OPENAPI fields among them), so we copy the header into
the scope before Karrio's ASGI app sees the request.
"""
from karrio.server.asgi import application as _karrio_app


async def application(scope, receive, send):
    if scope["type"] in ("http", "websocket"):
        for name, value in scope.get("headers") or ():
            if name == b"x-ingress-path" and value:
                ingress_path = value.decode("latin-1").rstrip("/")
                scope = {**scope, "root_path": ingress_path}
                break
    await _karrio_app(scope, receive, send)
