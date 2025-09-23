"""
Receives messages from Cost Anomaly alarms via SQS subscription to SNS.
Forwards the alarms to Slack, with an emoji that says good or bad.
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
    def __init__(self,  type, text, emoji):
        #type: plain_text
        self.type = type
        #text: text to be displayed
        self.text = text
        #emoji: boolean
        self.emoji = emoji

class Block:
    #def __init__(self, type,  text=None, fields=None):
    def __init__(self, type, **kwargs):
        #type: section
        self.type = type
        #fields: an array of fields in the section
        if kwargs.get("fields"):
            self.fields = kwargs.get("fields")
        if kwargs.get("text"):
            self.text = kwargs.get("text")

class Text:
    #def __init__(self, type, text, emoji):
    def __init__(self, type, text, **kwargs):
        #type: plain_text
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

def lambda_handler(event, context):

    print(f"Received event: {json.dumps(event)}")
    print(f"Function name: {context.function_name}")
    print(f"Remaining time: {context.get_remaining_time_in_millis()} ms")
    # print("event:" + event)
    # anomalyEvent = json.loads(event["Records"][0]["Sns"]["Message"])
    anomalyEvent = json.dumps(event)
    # print(anomalyEvent)

    message_id = 4

    #Total Cost of the Anomaly
    totalcostImpact = anomalyEvent["impact"]["totalImpact"]

    #Anomaly Detection Interval
    anomalyStartDate =  anomalyEvent["anomalyStartDate"]
    anomalyEndDate = anomalyEvent["anomalyEndDate"]

    #anomalyDetailsLink
    anomalyDetailsLink = anomalyEvent["anomalyDetailsLink"]

    #Blocks is the main array that holds the full message.
    blocks = []

    headerText = Text("plain_text", ":warning: Cost Anomaly Detected ", emoji = True)
    totalAnomalyCostText = Text("mrkdwn", "*Total Anomaly Cost*: $" + str(totalcostImpact))
    rootCausesHeaderText = Text("mrkdwn", "*Root Causes* :mag:")
    anomalyStartDateText = Text("mrkdwn", "*Anomaly Start Date*: " + str(anomalyStartDate))
    anomalyEndDateText = Text("mrkdwn", "*Anomaly End Date*: " + str(anomalyEndDate))
    anomalyDetailsLinkText = Text("mrkdwn", "*Anomaly Details Link*: " + str(anomalyDetailsLink))

    blocks.append(Block("header", text=headerText.__dict__))
    blocks.append(Block("section", text=totalAnomalyCostText.__dict__))
    blocks.append(Block("section", text=anomalyStartDateText.__dict__))
    blocks.append(Block("section", text=anomalyEndDateText.__dict__))
    blocks.append(Block("section", text=anomalyDetailsLinkText.__dict__))
    blocks.append(Block("section", text=rootCausesHeaderText.__dict__))

    for rootCause in anomalyEvent["rootCauses"]:
        fields = []
        for rootCauseAttribute in rootCause:
            if rootCauseAttribute == "linkedAccount":
                accountName = get_aws_account_name(rootCause[rootCauseAttribute])
                fields.append(Field("plain_text", "accountName"  + " : " + accountName, False))
            fields.append(Field("plain_text", rootCauseAttribute  + " : " + rootCause[rootCauseAttribute], False))
        blocks.append(Block("section", fields = [ob.__dict__ for ob in fields]))

    message_json = blocks= json.dumps([ob.__dict__ for ob in blocks])

    webhook = get_ssm_parameter(f'/cost_anomaly/lambda/slack_webhook_url')

    send_message_to_slack(webhook, message_json, message_id)

def send_message_to_slack(webhook, message_json, message_id):
    """
    Calls the Slack webhook with the formatted message. Returns success status.
    """
    if not webhook:
        log({'msg': 'Unable to send to Slack as webhook URL is not set',
             'messageId': message_id})
        return False
    jsondata = message_json
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
def get_aws_account_name(account_id):
    #Function is used to fetch account name corresponding to an account number. The account name is used to display a meaningful name in the Slack notification. For this function to operate, proper IAM permission should be granted to the Lambda function role.
    print("Fetching Account Name corresponding to accountId:" + account_id)

    #Initialise Organisations
    client = boto3.client('organizations')

    #Call describe_account in order to return the account_id corresponding to the account_number.
    response = client.describe_account(AccountId=account_id)

    accountName = response["Account"]["Name"]
    print("Fetching Account Name complete. Account Name:" + accountName)

    #Return the Account Name corresponding the Input Account ID.
    return response["Account"]["Name"]
def log(data):
    """
    Enriches the log message with the current time and prints it to standard out.
    """
    data['time'] = datetime.now().astimezone(tz=timezone.utc).isoformat()
    print(json.dumps(data))