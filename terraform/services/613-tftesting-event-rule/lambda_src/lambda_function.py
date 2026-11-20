import json
import logging
import os
import time
import uuid

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

events = boto3.client("events")
ssm = boto3.client("ssm")

POLL_SECONDS = 2
WAIT_SECONDS = 45  # function timeout is 60


def function_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    request_type = event.get("RequestType")
    if request_type == "RoundTripCheck":
        return _round_trip_check()
    if request_type == "ScheduledPing":
        return {"status": "ok", "message": "Scheduled rule delivered its fixed input"}
    if request_type == "LivenessCheck":
        return {"status": "ok"}

    if (
        event.get("source") == os.environ["EVENT_SOURCE"]
        and event.get("detail-type") == os.environ["EVENT_DETAIL_TYPE"]
    ):
        return _record_receipt(event)

    logger.warning("Unrecognized event; nothing to do")
    return {"status": "ignored"}


def _record_receipt(event):
    """Invoked by the pattern rule. Records the nonce so the round-trip check can see it."""
    nonce = event["detail"]["nonce"]
    ssm.put_parameter(
        Name=os.environ["RECEIPT_PARAM"],
        Value=nonce,
        Type="String",
        Overwrite=True,
    )
    logger.info("Recorded round-trip nonce %s", nonce)
    return {"status": "ok", "nonce": nonce}


def _round_trip_check():
    """
    Puts an event on the bus (through the VPC's EventBridge endpoint, since this function
    runs in private subnets) and waits for the pattern rule to deliver it back to this
    function. Raises on failure so tofu apply fails.
    """
    nonce = str(uuid.uuid4())
    response = events.put_events(
        Entries=[
            {
                "Source": os.environ["EVENT_SOURCE"],
                "DetailType": os.environ["EVENT_DETAIL_TYPE"],
                "Detail": json.dumps({"nonce": nonce}),
                "EventBusName": os.environ["EVENT_BUS_NAME"],
            }
        ]
    )
    if response.get("FailedEntryCount", 0) > 0:
        raise RuntimeError(f"Round-trip check FAILED: PutEvents rejected the event: {response['Entries']}")
    logger.info("Put round-trip event %s", nonce)

    deadline = time.monotonic() + WAIT_SECONDS
    while time.monotonic() < deadline:
        received = ssm.get_parameter(Name=os.environ["RECEIPT_PARAM"])["Parameter"]["Value"]
        if received == nonce:
            logger.info("Round-trip check passed for %s", nonce)
            return {"status": "ok", "nonce": nonce}
        time.sleep(POLL_SECONDS)

    raise RuntimeError(
        f"Round-trip check FAILED: event {nonce} was not delivered to the Lambda target "
        f"within {WAIT_SECONDS}s. Check the rule's FailedInvocations metric and the Lambda permission."
    )
