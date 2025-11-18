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

ssm_parameter_cache = {}


class Field:
    def __init__(self, type, text, emoji):
        self.type = type
        self.text = text
        self.emoji = emoji

class Block:
    def __init__(self, type, **kwargs):
        self.type = type
        if kwargs.get("fields"):
           self.fields = kwargs.get("fields")
        if kwargs.get("text"):
           self.text = kwargs.get("text")

class Text:
    def __init__(self, type, text, **kwargs):
        self.type = type
        self.text = text
        if kwargs.get("emoji"):
           self.emoji = kwargs.get("emoji")

def get_ssm_client():
    """
    Lazy initialization of boto3 SSM client.
    Prevents global instantiation to avoid NoRegionError during tests.
    """
    return boto3.client('ssm')


def get_ssm_parameter(name):
    """
    Retrieves an SSM parameter and caches the value to prevent duplicate API calls.
    Caches None if the parameter is not found or an error occurs.
    """
    if name not in ssm_parameter_cache:
        try:
            ssm_client = get_ssm_client()
            response = ssm_client.get_parameter(Name=name, WithDecryption=True)
            value = response['Parameter']['Value']
            ssm_parameter_cache[name] = value
        except ClientError as e:
            log({'msg': f'Error getting SSM parameter {name}: {e}'})
            ssm_parameter_cache[name] = None

    return ssm_parameter_cache[name]


def is_ignore_ok():
    """
    Returns the current value of the IGNORE_OK environment variable.
    This allows tests to patch the environment dynamically.
    """
    return os.environ.get('IGNORE_OK', 'false').lower() == 'true'


def lambda_handler(event, context):
    print(json.dumps(event))

    print("Retrieve Slack URL from Secrets Manager")

    slack_url = get_ssm_parameter(f'/cdap/sensitive/webhook/cost-anomaly')

    print("Slack Webhook URL retrieved")

    print("Initialise Slack Webhook Client")

    print("Decoding the SNS Message")
    anomalyEvent = json.loads(event["Records"][0]["Sns"]["Message"])

    # Total Cost of the Anomaly
    totalcostImpact = anomalyEvent["impact"]["totalImpact"]

    # Anomaly Detection Interval
    anomalyStartDate = anomalyEvent["anomalyStartDate"]
    anomalyEndDate = anomalyEvent["anomalyEndDate"]

    # anomalyDetailsLink
    anomalyDetailsLink = anomalyEvent["anomalyDetailsLink"]

    # Now, will start building the Slack Message.
    # Blocks is the main array thagit git holds the full message.
    # Instantiate an Object of the Class Block
    blocks = []

    # MessageFormatting - Keep Appending the blocks object. Order is important here.
    # First, Populating the 'Text' Object that is a subset of the Block object.
    headerText = Text("plain_text", ":warning: Cost Anomaly Detected ", emoji=True)
    totalAnomalyCostText = Text("mrkdwn", "*Total Anomaly Cost*: $" + str(totalcostImpact))
    rootCausesHeaderText = Text("mrkdwn", "*Root Causes* :mag:")
    anomalyStartDateText = Text("mrkdwn", "*Anomaly Start Date*: " + str(anomalyStartDate))
    anomalyEndDateText = Text("mrkdwn", "*Anomaly End Date*: " + str(anomalyEndDate))
    anomalyDetailsLinkText = Text("mrkdwn", "*Anomaly Details Link*: " + str(anomalyDetailsLink))

    # Second, Start appending the 'blocks' object with the header, totalAnomalyCost and rootCausesHeaderText
    blocks.append(Block("header", text=headerText.__dict__))
    blocks.append(Block("section", text=totalAnomalyCostText.__dict__))
    blocks.append(Block("section", text=anomalyStartDateText.__dict__))
    blocks.append(Block("section", text=anomalyEndDateText.__dict__))
    blocks.append(Block("section", text=anomalyDetailsLinkText.__dict__))
    blocks.append(Block("section", text=rootCausesHeaderText.__dict__))

    # Third, iterate through all possible root causes in the Anomaly Event and append the blocks as well as fields objects.
    for rootCause in anomalyEvent["rootCauses"]:
        fields = []
        for rootCauseAttribute in rootCause:
            if rootCauseAttribute == "linkedAccount":
                fields.append(Field("plain_text", "accountName" + " : " + "non-prod", False))
                fields.append(Field("plain_text", rootCauseAttribute + " : " + rootCause[rootCauseAttribute], False))
        blocks.append(Block("section", fields=[ob.__dict__ for ob in fields]))

    send_message_to_slack(slack_url, anomalyEvent, json.dumps([ob.__dict__ for ob in blocks]))

    return {
        'statusCode': 200,
        'responseMessage': 'Posted to Slack Channel Successfully'
    }


def send_message_to_slack(webhook, message, message_id):
    """
    Calls the Slack webhook with the formatted message. Returns success status.
    """
    if not webhook:
        log({'msg': 'Unable to send to Slack as webhook URL is not set',
             'messageId': message_id})
        return False
    jsondata = json.dumps(message)
    jsondataasbytes = jsondata.encode('utf-8')
    req = request.Request(webhook)
    req.add_header('Content-Type', 'application/json; charset=utf-8')
    req.add_header('Content-Length', str(len(jsondataasbytes)))
    try:
        with request.urlopen(req, jsondataasbytes) as resp:
            if resp.status == 200:
                log({'msg': 'Successfully sent message to Slack',
                     'messageId': message_id})
                return True
            log({'msg': f'Unsuccessful attempt to send message to Slack ({resp.status})',
                 'messageId': message_id})
            return False
    except URLError as e:
        log({'msg': f'Unsuccessful attempt to send message to Slack ({e.reason})',
             'messageId': message_id})
        return False


def log(data):
    """
    Enriches the log message with the current time and prints it to standard out.
    """
    data['time'] = datetime.now().astimezone(tz=timezone.utc).isoformat()
    print(json.dumps(data))
