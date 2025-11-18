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
    def __init__(self, type: object, text, emoji):
        self.type = type
        #text: text to be displayed
        self.text = text
        #emoji: boolean
        self.emoji = emoji


class Block:
    #def __init__(self, type,  text=None, fields=None):
    def __init__(self, type: object, **kwargs):
        self.type = type
        #fields: an array of fields in the section
        if kwargs.get("fields"):
            self.fields = kwargs.get("fields")
        if kwargs.get("text"):
            self.text = kwargs.get("text")


class Text:
    #def __init__(self, type, text, emoji):
    def __init__(self, type: object, text, **kwargs):
        self.type = type
        #text: text to be displayed
        self.text = text
        #emoji: boolean
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


def lambda_handler(event):
    print(json.dumps(event))

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
    total_anomaly_cost_text = Text("mrkdwn", "*Total Anomaly Cost*: $" + str(totalcost_impact))
    root_causes_header_text = Text("mrkdwn", "*Root Causes* :mag:")
    anomaly_start_date_text = Text("mrkdwn", "*Anomaly Start Date*: " + str(anomaly_start_date))
    anomaly_end_date_text = Text("mrkdwn", "*Anomaly End Date*: " + str(anomaly_end_date))
    anomaly_details_link_text = Text("mrkdwn", "*Anomaly Details Link*: " + str(anomaly_details_link))

    blocks.append(Block("header", text=header_text.__dict__))
    blocks.append(Block("section", text=total_anomaly_cost_text.__dict__))
    blocks.append(Block("section", text=anomaly_start_date_text.__dict__))
    blocks.append(Block("section", text=anomaly_end_date_text.__dict__))
    blocks.append(Block("section", text=anomaly_details_link_text.__dict__))
    blocks.append(Block("section", text=root_causes_header_text.__dict__))

    for root_cause in anomaly_event["rootCauses"]:
        fields = []
        for root_cause_attribute in root_cause:
            if root_cause_attribute == "linkedAccount":
                fields.append(Field("plain_text", "accountName" + " : " + "non-prod", False))
                fields.append(
                    Field("plain_text", root_cause_attribute + " : " + root_cause[root_cause_attribute], False))
        blocks.append(Block("section", fields=[ob.__dict__ for ob in fields]))

    send_message_to_slack(slack_url, anomaly_event, json.dumps([ob.__dict__ for ob in blocks]))

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
