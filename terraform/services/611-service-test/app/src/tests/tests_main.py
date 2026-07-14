import pytest
from unittest.mock import patch, MagicMock
from main import emit_metric, run_trace_example

@patch("datadog.statsd")
def test_emit_metric(mock_statsd):
    """Test that emit_metric calls statsd.gauge with correct args."""
    emit_metric("cdap.apm_test.synthetic_value", 42.0, tags=["env:test"])
    mock_statsd.gauge.assert_called_once_with(
        "cdap.apm_test.synthetic_value",
        42.0,
        tags=["env:test"],
    )

@patch("datadog.statsd")
@patch("main.tracer")
def test_run_trace_example(mock_tracer, mock_statsd):
    """Test that run_trace_example creates a span and emits a metric."""
    mock_span = MagicMock()
    mock_tracer.trace.return_value.__enter__ = MagicMock(return_value=mock_span)
    mock_tracer.trace.return_value.__exit__ = MagicMock(return_value=False)

    run_trace_example()

    mock_tracer.trace.assert_called_once_with(
        "apm-test.operation",
        service="apm-test",
        resource="test-run",
    )
    mock_span.set_tag.assert_any_call("env", "test")
    mock_statsd.gauge.assert_called_once()
