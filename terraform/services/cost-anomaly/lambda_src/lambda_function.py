"""
Receives messages from Cost Anomaly Monitor via SQS subscription to SNS.
Forwards the message to Slack channel #dasg_metrics_and_insights.
"""

from datetime import datetime, timezone
import json
import os
from urllib import request
from urllib.error import URLError
import boto3
from botocore.exceptions import ClientError

SSM_PARAMETER_CACHE = {}

# pylint: disable=too-few-public-methods
class Field:
    """Represents a field object from SNS JSON."""

    def __init__(self, field_type, text, emoji):
        """
        Initialize a Field object.

        Args:
            field_type: The type of the field
            text: Text to be displayed
            emoji: Boolean indicating if emoji should be used
        """
        self.type = field_type
        self.text = text
        self.emoji = emoji

# pylint: disable=too-few-public-methods
class Block:
    """Represents a block object from SNS JSON."""

    def __init__(self, block_type, **kwargs):
        """
        Initialize a Block object.

        Args:
            block_type: The type of the block
            **kwargs: Optional fields (fields, text)
        """
        self.type = block_type
        if kwargs.get("fields"):
            self.fields = kwargs.get("fields")
        if kwargs.get("text"):
            self.text = kwargs.get("text")

# pylint: disable=too-few-public-methods
class Text:
    """Represents a text object from SNS JSON."""

    def __init__(self, text_type, text, **kwargs):
        """
        Initialize a Text object.

        Args:
            text_type: The type of the text
            text: Text to be displayed
            **kwargs: Optional emoji parameter
        """
        self.type = text_type
        self.text = text
        if kwargs.get("emoji"):
            self.emoji = kwargs.get("emoji")


def get_ssm_client():
    """
    Lazy initialization of boto3 SSM client.
    Prevents global instantiation to avoid NoRegionError during tests.

    Returns:
        boto3.client: SSM client instance
    """
    return boto3.client('ssm')


def get_ssm_parameter(name):
    """
    Retrieve an SSM parameter and cache the value to prevent duplicate API calls.
    Caches None if the parameter is not found or an error occurs.

    Args:
        name: The name of the SSM parameter

    Returns:
        str or None: The parameter value or None if not found
    """
    if name not in SSM_PARAMETER_CACHE:
        try:
            ssm_client = get_ssm_client()
            response = ssm_client.get_parameter(Name=name, WithDecryption=True)
            value = response['Parameter']['Value']
            SSM_PARAMETER_CACHE[name] = value
        except ClientError as error:
            log({'msg': f'Error getting SSM parameter {name}: {error}'})
            SSM_PARAMETER_CACHE[name] = None

    return SSM_PARAMETER_CACHE[name]


def is_ignore_ok():
    """
    Return the current value of the IGNORE_OK environment variable.
    This allows tests to patch the environment dynamically.

    Returns:
        bool: True if IGNORE_OK is set to 'true', False otherwise
    """
    return os.environ.get('IGNORE_OK', 'false').lower() == 'true'

# pylint: disable=too-many-locals
def lambda_handler(event,context):
    """
    Handle incoming Lambda events from Cost Anomaly Monitor.

    Args:
        event: Lambda event containing SNS message
        context: Lambda context (unused)

    Returns:
        dict: Status code and response message
    """
    print(json.dumps(event))
    print(json.dumps(context))

    print("Retrieve Slack URL from Secrets Manager")

    slack_url = get_ssm_parameter('/cdap/sensitive/webhook/cost-anomaly')

    print("Slack Webhook URL retrieved")

    print("Initialise Slack Webhook Client")

    print("Decoding the SNS Message")
    anomaly_event = json.loads(event["Records"][0]["Sns"]["Message"])

    totalcost_impact = anomaly_event["impact"]["totalImpact"]

    anomaly_start_date = anomaly_event["anomalyStartDate"]
    anomaly_end_date = anomaly_event["anomalyEndDate"]

    anomaly_details_link = anomaly_event["anomalyDetailsLink"]

    blocks = []

    header_text = Text("plain_text", ":warning: Cost Anomaly Detected ", emoji=True)
    total_anomaly_cost_text = Text(
        "mrkdwn", f"*Total Anomaly Cost*: ${totalcost_impact}"
    )
    root_causes_header_text = Text("mrkdwn", "*Root Causes* :mag:")
    anomaly_start_date_text = Text(
        "mrkdwn", f"*Anomaly Start Date*: {anomaly_start_date}"
    )
    anomaly_end_date_text = Text(
        "mrkdwn", f"*Anomaly End Date*: {anomaly_end_date}"
    )
    anomaly_details_text = Text(
        "mrkdwn", f"*Anomaly Details Link*: {anomaly_details_link}"
    )

    blocks.append(Block("header", text=header_text.__dict__))
    blocks.append(Block("section", text=total_anomaly_cost_text.__dict__))
    blocks.append(Block("section", text=anomaly_start_date_text.__dict__))
    blocks.append(Block("section", text=anomaly_end_date_text.__dict__))
    blocks.append(Block("section", text=anomaly_details_text.__dict__))
    blocks.append(Block("section", text=root_causes_header_text.__dict__))

    for root_cause in anomaly_event["rootCauses"]:
        fields = []
        for root_cause_attribute in root_cause:
            if root_cause_attribute == "linkedAccount":
                fields.append(
                    Field("plain_text", "accountName : non-prod", False)
                )
                fields.append(
                    Field(
                        "plain_text",
                        f"{root_cause_attribute} : {root_cause[root_cause_attribute]}",
                        False
                    )
                )
        blocks.append(Block("section", fields=[ob.__dict__ for ob in fields]))

    send_message_to_slack(
        slack_url,
        anomaly_event,
        json.dumps([ob.__dict__ for ob in blocks])
    )

    return {
        'statusCode': 200,
        'responseMessage': 'Posted to Slack Channel Successfully'
    }


def send_message_to_slack(webhook, message, message_id):
    """
    Call the Slack webhook with the formatted message.

    Args:
        webhook: Slack webhook URL
        message: Message content to send
        message_id: Identifier for the message

    Returns:
        bool: True if successful, False otherwise
    """
    if not webhook:
        log({
            'msg': 'Unable to send to Slack as webhook URL is not set',
            'messageId': message_id
        })
        return False

    jsondata = json.dumps(message)
    jsondataasbytes = jsondata.encode('utf-8')
    req = request.Request(webhook)
    req.add_header('Content-Type', 'application/json; charset=utf-8')
    req.add_header('Content-Length', str(len(jsondataasbytes)))

    try:
        with request.urlopen(req, jsondataasbytes) as resp:
            if resp.status == 200:
                log({
                    'msg': 'Successfully sent message to Slack',
                    'messageId': message_id
                })
                return True
            log({
                'msg': f'Unsuccessful attempt to send message to Slack ({resp.status})',
                'messageId': message_id
            })
            return False
    except URLError as error:
        log({
            'msg': f'Unsuccessful attempt to send message to Slack ({error.reason})',
            'messageId': message_id
        })
        return False


def log(data):
    """
    Enrich the log message with the current time and print it to standard out.

    Args:
        data: Dictionary containing log data
    """
    data['time'] = datetime.now().astimezone(tz=timezone.utc).isoformat()
    print(json.dumps(data))
