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
const { spawn } = require("child_process");

const PUBLIC_PORT = parseInt(process.env.PORT || "3002", 10);
const INTERNAL_PORT = parseInt(process.env.INTERNAL_PORT || "3003", 10);

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

  const proxyReq = http.request(
    {
      host: "127.0.0.1",
      port: INTERNAL_PORT,
      method: clientReq.method,
      path: clientReq.url,
      headers: clientReq.headers,
    },
    (proxyRes) => {
      const headers = { ...proxyRes.headers };
      if (headers.location) {
        headers.location = rewriteLocation(headers.location, ingressPath);
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
