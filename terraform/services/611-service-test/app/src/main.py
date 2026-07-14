import os
import time
import logging
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import ddtrace.auto
from ddtrace import tracer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Read Datadog config from environment variables
# These are injected by the service module automatically:
# DD_SERVICE, DD_ENV, DD_VERSION, DD_TAGS
# -------------------------------------------------------
DD_SERVICE = os.environ.get("DD_SERVICE", "apm-test")
DD_ENV     = os.environ.get("DD_ENV", "unknown")
DD_VERSION = os.environ.get("DD_VERSION", "unknown")

# -------------------------------------------------------
# Minimal HTTP health server
# Runs in a background thread — no filesystem writes needed
# Compatible with readonlyRootFilesystem = true
# -------------------------------------------------------
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress default HTTP server logs


def start_health_server(port: int = 8080):
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    logger.info(f"Health server listening on port {port}")


# -------------------------------------------------------
# Metric emission — all tags derived from environment
# -------------------------------------------------------
def emit_metric(metric_name: str, value: float, tags: list[str] = None):
    from datadog import statsd
    tags = tags or []
    statsd.gauge(metric_name, value, tags=tags)
    logger.info(f"Emitted metric: {metric_name}={value} tags={tags}")


def run_trace_example():
    with tracer.trace("apm-test.operation", service=DD_SERVICE, resource="test-run") as span:
        span.set_tag("env",     DD_ENV)
        span.set_tag("version", DD_VERSION)

        logger.info(f"Running APM trace — service={DD_SERVICE} env={DD_ENV} version={DD_VERSION}")
        time.sleep(0.1)

        emit_metric(
            "cdap.apm_test.synthetic_value",
            value=42.0,
            tags=[
                f"env:{DD_ENV}",
                f"service:{DD_SERVICE}",
                f"version:{DD_VERSION}",
            ],
        )

        logger.info("Trace complete.")


if __name__ == "__main__":
    interval = int(os.environ.get("EMIT_INTERVAL_SECONDS", 30))
    logger.info(f"Starting {DD_SERVICE} — env={DD_ENV} version={DD_VERSION} interval={interval}s")

    start_health_server()

    while True:
        try:
            run_trace_example()
        except Exception as e:
            logger.error(f"Error during trace/metric emission: {e}")
        time.sleep(interval)
