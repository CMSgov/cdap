import os
import time
import socket
import logging
import threading
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

os.environ.setdefault("DD_TRACE_AGENT_URL", "http://localhost:8126")

import ddtrace.auto
from ddtrace import tracer
from ddtrace.propagation.http import HTTPPropagator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DD_SERVICE    = os.environ.get("DD_SERVICE", "tftesting")
DD_ENV        = os.environ.get("DD_ENV", "test")
DD_VERSION    = os.environ.get("DD_VERSION", "unknown")

# Service Connect config — set DOWNSTREAM_URL in Service A's container env
DOWNSTREAM_URL = os.environ.get("DOWNSTREAM_URL", "")
EMIT_INTERVAL  = int(os.environ.get("EMIT_INTERVAL_SECONDS", 30))


def wait_for_datadog_agent(host="localhost", port=8126, timeout=60, interval=2):
    start = time.time()
    while time.time() - start < timeout:
        try:
            with socket.create_connection((host, port), timeout=2):
                logger.info(f"Datadog agent ready at {host}:{port}")
                return True
        except (ConnectionRefusedError, OSError):
            logger.warning(f"Datadog agent not ready, retrying in {interval}s...")
            time.sleep(interval)
    logger.warning("Datadog agent did not become ready in time — traces may be dropped.")
    return False


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")

        elif self.path == "/ping":
            # Service B responds here — confirms Service Connect is working
            self.send_response(200)
            self.end_headers()
            self.wfile.write(
                f"pong from {DD_SERVICE} env={DD_ENV} version={DD_VERSION}".encode()
            )

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


def start_health_server(port: int = 8080):
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    logger.info(f"Health server listening on port {port}")


def emit_metric(metric_name: str, value: float, tags: list[str] = None):
    from datadog import statsd
    tags = tags or []
    statsd.gauge(metric_name, value, tags=tags)
    logger.info(f"Emitted metric: {metric_name}={value} tags={tags}")


def call_downstream():
    """Call Service B over Service Connect and trace the request."""
    if not DOWNSTREAM_URL:
        return

    with tracer.trace("service-connect.call", service=DD_SERVICE, resource=DOWNSTREAM_URL) as span:
        span.set_tag("downstream.url", DOWNSTREAM_URL)
        span.set_tag("env", DD_ENV)
        try:
            req = urllib.request.Request(DOWNSTREAM_URL)

            HTTPPropagator.inject(span.context, req.headers)

            with urllib.request.urlopen(req, timeout=5) as resp:
                body = resp.read().decode()
                span.set_tag("downstream.status", resp.status)
                span.set_tag("downstream.response", body)
                logger.info(f"Service Connect call succeeded: {body}")
                emit_metric(
                    "cdap.service_connect.call",
                    value=1.0,
                    tags=[
                        f"env:{DD_ENV}",
                        f"service:{DD_SERVICE}",
                        "status:success",
                    ],
                )
        except Exception as e:
            span.set_tag("error", True)
            span.set_tag("error.message", str(e))
            logger.exception(f"Service Connect call failed: {e}")
            emit_metric(
                "cdap.service_connect.call",
                value=0.0,
                tags=[
                    f"env:{DD_ENV}",
                    f"service:{DD_SERVICE}",
                    "status:failure",
                ],
            )


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

        # If this is Service A, call Service B over Service Connect
        call_downstream()

        logger.info("Trace complete.")


if __name__ == "__main__":
    logger.info(f"Starting {DD_SERVICE} — env={DD_ENV} version={DD_VERSION} interval={EMIT_INTERVAL}s")

    start_health_server()
    wait_for_datadog_agent()

    while True:
        try:
            run_trace_example()
        except Exception as e:
            logger.exception(f"Error during trace/metric emission: {e}")
        time.sleep(EMIT_INTERVAL)
