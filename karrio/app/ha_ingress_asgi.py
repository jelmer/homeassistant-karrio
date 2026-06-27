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

        if scope["type"] == "http" and scope["path"] in ("", "/"):
            target = f"{ingress_path}/admin/" if ingress_path else "/admin/"
            await send({
                "type": "http.response.start",
                "status": 302,
                "headers": [
                    (b"location", target.encode("latin-1")),
                    (b"content-length", b"0"),
                ],
            })
            await send({"type": "http.response.body", "body": b""})
            return

    await _karrio_app(scope, receive, send)
