import json
import logging
import os

import boto3

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
    param_name = os.environ["SSM_PARAM_PATH"]

    # Validates: egress rules, IAM SSM permissions, KMS decrypt permission
    response = ssm.get_parameter(Name=param_name, WithDecryption=True)
    value = response["Parameter"]["Value"]

    if not value:
        raise ValueError("SSM parameter was empty")

    if os.environ.get("ENVIRONMENT") != "tftesting":
        raise ValueError(
            f"ENVIRONMENT env var not set correctly: {os.environ.get('ENVIRONMENT')!r}"
        )

    logger.info("Liveness check passed. SSM value retrieved successfully.")
    return {"status": "ok", "message": "Lambda is healthy"}
