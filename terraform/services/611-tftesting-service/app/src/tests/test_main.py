import os
import pytest
from unittest.mock import patch, MagicMock, call


# -------------------------------------------------------
# Set DD env vars before importing main so module-level
# constants (DD_SERVICE, DD_ENV, DD_VERSION) are correct
# -------------------------------------------------------
os.environ.setdefault("DD_SERVICE", "apm-test")
os.environ.setdefault("DD_ENV",     "test")
os.environ.setdefault("DD_VERSION", "0.0.1")

from main import emit_metric, run_trace_example, HealthHandler, DD_SERVICE, DD_ENV, DD_VERSION


# -------------------------------------------------------
# emit_metric tests
# -------------------------------------------------------

@patch("datadog.statsd.gauge")
def test_emit_metric_calls_gauge(mock_gauge):
    """emit_metric should call statsd.gauge with correct args."""
    emit_metric("cdap.apm_test.synthetic_value", 42.0, tags=["env:test"])
    mock_gauge.assert_called_once_with(
        "cdap.apm_test.synthetic_value",
        42.0,
        tags=["env:test"],
    )


@patch("datadog.statsd.gauge")
def test_emit_metric_defaults_empty_tags(mock_gauge):
    """emit_metric should default to empty tags list."""
    emit_metric("cdap.apm_test.synthetic_value", 1.0)
    mock_gauge.assert_called_once_with(
        "cdap.apm_test.synthetic_value",
        1.0,
        tags=[],
    )


# -------------------------------------------------------
# run_trace_example tests
# -------------------------------------------------------

@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_creates_span(mock_tracer, mock_gauge):
    """run_trace_example should create a span with correct service and resource."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    run_trace_example()

    mock_tracer.trace.assert_called_once_with(
        "apm-test.operation",
        service=DD_SERVICE,
        resource="test-run",
    )


@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_sets_tags(mock_tracer, mock_gauge):
    """run_trace_example should set env and version tags on the span."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    run_trace_example()

    mock_span.set_tag.assert_any_call("env",     DD_ENV)
    mock_span.set_tag.assert_any_call("version", DD_VERSION)


@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_emits_metric(mock_tracer, mock_gauge):
    """run_trace_example should emit a metric with correct tags."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    run_trace_example()

    mock_gauge.assert_called_once_with(
        "cdap.apm_test.synthetic_value",
        42.0,
        tags=[
            f"env:{DD_ENV}",
            f"service:{DD_SERVICE}",
            f"version:{DD_VERSION}",
        ],
    )


# -------------------------------------------------------
# HealthHandler tests
# -------------------------------------------------------

def test_health_handler_returns_200():
    """HealthHandler should return 200 for /health."""
    handler = HealthHandler.__new__(HealthHandler)
    handler.path = "/health"
    handler.send_response = MagicMock()
    handler.end_headers   = MagicMock()
    handler.wfile         = MagicMock()

    handler.do_GET()

    handler.send_response.assert_called_once_with(200)
    handler.wfile.write.assert_called_once_with(b"OK")


def test_health_handler_returns_404():
    """HealthHandler should return 404 for unknown paths."""
    handler = HealthHandler.__new__(HealthHandler)
    handler.path = "/unknown"
    handler.send_response = MagicMock()
    handler.end_headers   = MagicMock()
    handler.wfile         = MagicMock()

    handler.do_GET()

    handler.send_response.assert_called_once_with(404)


def test_health_handler_returns_404_for_root():
    """HealthHandler should return 404 for / (only /health is valid)."""
    handler = HealthHandler.__new__(HealthHandler)
    handler.path = "/"
    handler.send_response = MagicMock()
    handler.end_headers   = MagicMock()
    handler.wfile         = MagicMock()

    handler.do_GET()

    handler.send_response.assert_called_once_with(404)
