// HA-ingress-aware HTTP front for the Karrio dashboard.
//
// The Next.js standalone server bakes basePath into the build, but the
// per-session ingress prefix HA sends in X-Ingress-Path isn't known
// until runtime. We work around that by running Next on a private
// localhost port and reverse-proxying it from the public port,
// applying the same trick as the karrio ASGI shim: strip Origin: null,
// trust X-Ingress-Path as the script prefix, and rewrite outgoing
// Location headers that start with "/" to include the prefix.

const http = require("http");
const { URL } = require("url");
const { spawn } = require("child_process");

const PUBLIC_PORT = parseInt(process.env.PORT || "3002", 10);
const INTERNAL_PORT = parseInt(process.env.INTERNAL_PORT || "3003", 10);

// Browser-facing requests for these path prefixes belong to the karrio
// API, not the Next.js dashboard. Forward them to the sibling karrio
// addon at KARRIO_URL.
const KARRIO_URL = process.env.KARRIO_URL || "";
const KARRIO_PROXY_PREFIXES = [
  "/v1/",
  "/graphql",
  "/openapi",
  "/static/",
  "/admin/",
  "/login/",
  "/logout/",
  "/api/v1/",
];

function shouldProxyToKarrio(pathname) {
  return KARRIO_URL && KARRIO_PROXY_PREFIXES.some((p) => pathname === p || pathname.startsWith(p));
}

let karrioTarget = null;
if (KARRIO_URL) {
  const u = new URL(KARRIO_URL);
  karrioTarget = {
    host: u.hostname,
    port: parseInt(u.port || (u.protocol === "https:" ? "443" : "80"), 10),
    protocol: u.protocol,
  };
}

// Boot Next.js standalone server on the internal port.
const nextProc = spawn(
  process.execPath,
  ["apps/dashboard/server.js"],
  {
    cwd: __dirname,
    env: {
      ...process.env,
      PORT: String(INTERNAL_PORT),
      HOSTNAME: "127.0.0.1",
    },
    stdio: "inherit",
  },
);
nextProc.on("exit", (code, signal) => {
  console.error(`[ingress] Next.js exited code=${code} signal=${signal}`);
  process.exit(code ?? 1);
});

function rewriteLocation(value, prefix) {
  if (!prefix) return value;
  if (!value.startsWith("/")) return value;
  if (value.startsWith("//")) return value;
  if (value.startsWith(prefix + "/") || value === prefix) return value;
  return prefix + value;
}

const proxy = http.createServer((clientReq, clientRes) => {
  const ingressPath = (clientReq.headers["x-ingress-path"] || "").replace(/\/$/, "");

  // Strip Origin: null so any downstream CSRF check falls back to Referer.
  if (clientReq.headers["origin"] === "null") {
    delete clientReq.headers["origin"];
  }

  // Decide whether this request goes to karrio or Next.js, based on
  // the path. NextAuth's /api/auth/* stays on Next.js; karrio's
  // /api/v1/* goes to karrio.
  const pathname = clientReq.url.split("?")[0];
  const useKarrio = karrioTarget && shouldProxyToKarrio(pathname);
  const upstream = useKarrio
    ? { host: karrioTarget.host, port: karrioTarget.port }
    : { host: "127.0.0.1", port: INTERNAL_PORT };

  // When forwarding to karrio, rewrite the Host header so karrio sees
  // its own hostname (otherwise its CSRF/ALLOWED_HOSTS checks may
  // reject the request).
  const upstreamHeaders = { ...clientReq.headers };
  if (useKarrio) {
    upstreamHeaders.host = `${karrioTarget.host}:${karrioTarget.port}`;
    // karrio's ASGI shim treats X-Ingress-Path as its script prefix; we
    // don't want it confusing karrio with the dashboard's ingress path.
    delete upstreamHeaders["x-ingress-path"];
  }

  const proxyReq = http.request(
    {
      host: upstream.host,
      port: upstream.port,
      method: clientReq.method,
      path: clientReq.url,
      headers: upstreamHeaders,
    },
    (proxyRes) => {
      const headers = { ...proxyRes.headers };
      if (headers.location) {
        headers.location = rewriteLocation(headers.location, ingressPath);
      }
      // HA serves the dashboard in a cross-origin iframe; Next.js's default
      // X-Frame-Options: SAMEORIGIN (and any CSP frame-ancestors directive)
      // would block rendering. Strip them when we're being framed via
      // ingress.
      if (ingressPath) {
        delete headers["x-frame-options"];
        if (headers["content-security-policy"]) {
          headers["content-security-policy"] = headers["content-security-policy"]
            .split(";")
            .map((d) => d.trim())
            .filter((d) => !/^frame-ancestors\b/i.test(d))
            .join("; ");
        }
      }
      clientRes.writeHead(proxyRes.statusCode, proxyRes.statusMessage, headers);
      proxyRes.pipe(clientRes);
    },
  );

  proxyReq.on("error", (err) => {
    console.error(`[ingress] upstream error: ${err.message}`);
    if (!clientRes.headersSent) {
      clientRes.writeHead(502, { "content-type": "text/plain" });
    }
    clientRes.end("Upstream Next.js error");
  });

  clientReq.pipe(proxyReq);
});

proxy.listen(PUBLIC_PORT, "0.0.0.0", () => {
  console.log(`[ingress] proxy listening on :${PUBLIC_PORT} -> 127.0.0.1:${INTERNAL_PORT}`);
});

["SIGINT", "SIGTERM"].forEach((sig) => {
  process.on(sig, () => {
    nextProc.kill(sig);
    proxy.close(() => process.exit(0));
  });
});
