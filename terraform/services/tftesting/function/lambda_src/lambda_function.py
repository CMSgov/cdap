import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")

def function_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    request_type = event.get("RequestType") or event.get("source", "")

    if request_type == "LivenessCheck":
        return _liveness_check()

    if os.environ.get("DD_SERVICE") is not None:
        _run_datadog_test()

    logger.warning("Unknown RequestType: %s", request_type)
    return {"status": "ok", "event": event}


def _run_datadog_test():
    from ddtrace import tracer
    from datadog_lambda.metric import lambda_metric

    try:
        # DATADOG TEST: add custom tags to the lambda function span
        current_span = tracer.current_span()
        if current_span:
            current_span.set_tag("cdap_test.id", "123456")

        # Submit custom span
        with tracer.trace("cdap_test.span_test"):
            print("CDAP Lambda test span.")

        # Submit custom metric
        lambda_metric(
            metric_name="cdap_test.metric_value_test",
            value=12.45,
            tags=["product:latte", "order:online"],
        )
    except Exception:
        logger.warning("Datadog test skipped due to runtime error", exc_info=True)


def _liveness_check():
    """
    Validates that the function can reach dependencies.
    Raises on failure so tofu apply fails.
    """
    # --- Validate SSM parameter is retrievable based on ssm_parameter_paths
    param_name = os.environ["SSM_PARAM_PATH"]
    _assert_ssm_readable(param_name, label="ssm_parameter_paths grant")

    # --- Validate SSM parameter is retrievable based on inline policy grant
    inline_param_name = os.environ["INLINE_POLICY_PARAM_PATH"]
    _assert_ssm_readable(inline_param_name, label="inline policy grant")

    logger.info("Liveness check passed. All SSM parameters retrieved successfully.")
    return {"status": "ok", "message": "Lambda is healthy"}


def _assert_ssm_readable(param_name: str, label: str) -> str:
    """
    Attempts to read an SSM SecureString parameter.
    Raises on failure with a descriptive message.
    Returns the parameter value on success.
    """
    try:
        response = ssm.get_parameter(Name=param_name, WithDecryption=True)
        value = response["Parameter"]["Value"]
    except ClientError as e:
        raise RuntimeError(
            f"Liveness check FAILED [{label}]: Could not read that SSM parameter "
            f"'{param_name}': {e}"
        ) from e

    if not value:
        raise ValueError(
            f"Liveness check FAILED [{label}]: SSM parameter '{param_name}' was empty"
        )

    logger.info(
        "SSM parameter readable [%s]: %s",
        label,
        param_name,
    )
    return value
