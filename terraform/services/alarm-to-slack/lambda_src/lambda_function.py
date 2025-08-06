"""
Receives messages from CloudWatch alarms via SQS subscription to SNS.
Forwards the alarms to Slack, with an emoji that says good or bad.
"""

from datetime import datetime, timezone
import json
import os
import re
from urllib import request
from urllib.error import URLError
import boto3
from botocore.exceptions import ClientError

ssm_client = boto3.client('ssm')

ssm_parameter_cache = {}

ignore_ok_apps = []

def initialize_ignore_ok_list(target_list):
    """Initializes the target_list from the environment variable."""
    ignore_ok_string = os.environ.get('IGNORE_OK_APPS', '')
    target_list.clear()
    target_list.extend(
        app.strip() for app in ignore_ok_string.split(',') if app.strip()
    )

initialize_ignore_ok_list(ignore_ok_apps)

def get_ssm_parameter(name):
    """
    Retrieves an SSM parameter and caches the value to prevent duplicate API calls.
    Returns None if the parameter is not found or an error occurs.
    """
    if name in ssm_parameter_cache:
        return ssm_parameter_cache[name]

    try:
        response = ssm_client.get_parameter(
            Name=name,
            WithDecryption=True
        )
        value = response['Parameter']['Value']
        ssm_parameter_cache[name] = value
        return value
    except ClientError as e:
        log({'msg': f'Error getting SSM parameter {name}: {e}'})
        return None

def lambda_handler(event, _):
    """
    Main entry point for the Lambda function.
    It iterates through the SQS records, processes each CloudWatch alarm,
    and forwards it to the appropriate Slack channel.
    """
    processed_count = 0
    for record in event['Records']:
        message = enriched_cloudwatch_message(record)
        if message:
            app = message.get('App')
            if app:
                webhook = get_ssm_parameter(f'/{app}/lambda/slack_webhook_url')
                if webhook:
                    send_message_to_slack(webhook, message, record.get('messageId'))
                    processed_count += 1
                else:
                    log({'messageId': record.get('messageId'),
                         'msg': f'Could not find Slack webhook for app: {app}'})
    return {
        'statusCode': 200,
        'body': f'Processed {processed_count} messages successfully'
    }

def cloudwatch_message(record):
    """
    Parses the SQS record for the CloudWatch Alarm JSON payload.
    Returns the parsed message dictionary or None if parsing fails.
    """
    try:
        body_s = record['body']
        body = json.loads(body_s)
        message_s = body['Message']
        message = json.loads(message_s)

        if message.get('OldStateValue'):
            return message
    except json.JSONDecodeError:
        log({'msg': 'Did not receive an SNS Cloudwatch payload',
             'messageId': record.get('messageId')})
    return None

def enriched_cloudwatch_message(record):
    """
    Parses the CloudWatch message, extracts the app and env from the alarm name,
    and enriches it with an emoji for display.
    """
    message = cloudwatch_message(record)
    if message:
        alarm_name = message.get('AlarmName')
        if alarm_name:
            match = re.match(r'^(?P<app>[a-zA-Z0-9]+)-.*', alarm_name)
            if match:
                app_name = match.group('app')
                message['App'] = app_name

                env_match = re.match(
                    r'^[a-zA-Z0-9]+-(?P<env>[a-zA-Z0-9]+)-.*',
                    alarm_name)
                if env_match:
                    message['Env'] = env_match.group('env')

                log({'App': app_name,
                     'AlarmName': alarm_name,
                     'NewStateValue': message.get('NewStateValue'),
                     'OldStateValue': message.get('OldStateValue'),
                     'StateChangeTime': message.get('StateChangeTime'),
                     'msg': 'Received CloudWatch Alarm',
                     'messageId': record.get('messageId')})

                if message['NewStateValue'] == 'OK' and app_name in ignore_ok_apps:
                    return None

                if message['NewStateValue'] == 'OK':
                    message['Emoji'] = ':checked:'
                else:
                    message['Emoji'] = ':anger:'
            else:
                log({'msg': f'AlarmName "{alarm_name}" does not match expected format',
                     'messageId': record.get('messageId')})
                return None
        else:
            log({'msg': 'AlarmName not found in message',
                 'messageId': record.get('messageId')})
            return None
    return message

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
