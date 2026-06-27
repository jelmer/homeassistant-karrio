# Gunicorn configuration for karrio's ASGI server.
# Lifted from karrio's upstream apps/api/gunicorn-cfg.py; the addon's
# run.sh sets KARRIO_HTTP_PORT and KARRIO_WORKERS before exec.
import decouple

KARRIO_HOST = decouple.config("KARRIO_HTTP_HOST", default="0.0.0.0")
KARRIO_PORT = decouple.config("KARRIO_HTTP_PORT", default=5002)

bind = f"{KARRIO_HOST}:{KARRIO_PORT}"
accesslog = "-"
errorlog = "-"
loglevel = decouple.config("KARRIO_LOG_LEVEL", default="info")
capture_output = True
enable_stdio_inheritance = True
workers = decouple.config("KARRIO_WORKERS", default=2, cast=int)
