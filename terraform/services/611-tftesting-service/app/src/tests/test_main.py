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

from main import emit_metric, run_trace_example, call_downstream, HealthHandler, DD_SERVICE, DD_ENV, DD_VERSION


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

@patch("main.call_downstream")
@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_creates_span(mock_tracer, mock_gauge, mock_downstream):
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


@patch("main.call_downstream")   # 👈 add this patch
@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_sets_tags(mock_tracer, mock_gauge, mock_downstream):
    """run_trace_example should set env and version tags on the span."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    run_trace_example()

    mock_span.set_tag.assert_any_call("env",     DD_ENV)
    mock_span.set_tag.assert_any_call("version", DD_VERSION)


@patch("main.call_downstream")   # 👈 add this patch
@patch("datadog.statsd.gauge")
@patch("main.tracer")
def test_run_trace_example_emits_metric(mock_tracer, mock_gauge, mock_downstream):
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

def test_health_handler_returns_200_for_ping():
    """HealthHandler should return 200 for /ping with pong body."""
    handler = HealthHandler.__new__(HealthHandler)
    handler.path = "/ping"
    handler.send_response = MagicMock()
    handler.end_headers   = MagicMock()
    handler.wfile         = MagicMock()

    handler.do_GET()

    handler.send_response.assert_called_once_with(200)
    written = handler.wfile.write.call_args[0][0]
    assert b"pong" in written


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

# -------------------------------------------------------
# call_downstream tests
# -------------------------------------------------------

@patch("main.tracer")
def test_call_downstream_skips_when_no_url(mock_tracer):
    """call_downstream should do nothing when DOWNSTREAM_URL is empty."""
    with patch("main.DOWNSTREAM_URL", ""):
        from main import call_downstream
        call_downstream()
        mock_tracer.trace.assert_not_called()


@patch("main.DOWNSTREAM_URL", "http://tftesting-b:8081/ping")
@patch("datadog.statsd.gauge")
@patch("main.tracer")
@patch("main.HTTPPropagator")
@patch("urllib.request.urlopen")
def test_call_downstream_success(mock_urlopen, mock_propagator, mock_tracer, mock_gauge):
    """call_downstream should emit success metric on 200 response."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    # mock a successful HTTP response
    mock_response = MagicMock()
    mock_response.status = 200
    mock_response.read.return_value = b"pong from tftesting-b"
    mock_response.__enter__ = MagicMock(return_value=mock_response)
    mock_response.__exit__ = MagicMock(return_value=False)
    mock_urlopen.return_value = mock_response

    from main import call_downstream
    call_downstream()

    mock_gauge.assert_called_once_with(
        "cdap.service_connect.call",
        1.0,
        tags=[
            f"env:{DD_ENV}",
            f"service:{DD_SERVICE}",
            "status:success",
        ],
    )

@patch("main.DOWNSTREAM_URL", "http://tftesting-b:8081/ping")
@patch("datadog.statsd.gauge")
@patch("main.tracer")
@patch("main.HTTPPropagator")
@patch("urllib.request.urlopen")
def test_call_downstream_failure(mock_urlopen, mock_propagator, mock_tracer, mock_gauge):
    """call_downstream should emit failure metric when request fails."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    # simulate a connection error
    mock_urlopen.side_effect = Exception("connection refused")

    from main import call_downstream
    call_downstream()

    mock_gauge.assert_called_once_with(
        "cdap.service_connect.call",
        0.0,
        tags=[
            f"env:{DD_ENV}",
            f"service:{DD_SERVICE}",
            "status:failure",
        ],
    )
    mock_span.set_tag.assert_any_call("error", True)


@patch("main.DOWNSTREAM_URL", "http://tftesting-b:8081/ping")
@patch("datadog.statsd.gauge")
@patch("main.tracer")
@patch("main.HTTPPropagator")
@patch("urllib.request.urlopen")
def test_call_downstream_sets_span_tags(mock_urlopen, mock_propagator, mock_tracer, mock_gauge):
    """call_downstream should set downstream URL and env tags on span."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    mock_response = MagicMock()
    mock_response.status = 200
    mock_response.read.return_value = b"pong"
    mock_response.__enter__ = MagicMock(return_value=mock_response)
    mock_response.__exit__ = MagicMock(return_value=False)
    mock_urlopen.return_value = mock_response

    from main import call_downstream
    call_downstream()

    mock_span.set_tag.assert_any_call("downstream.url", "http://tftesting-b:8081/ping")
    mock_span.set_tag.assert_any_call("env", DD_ENV)
