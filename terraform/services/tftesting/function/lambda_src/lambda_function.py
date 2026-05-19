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

    logger.warning("Unknown RequestType: %s", request_type)
    return {"status": "ok", "event": event}


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
