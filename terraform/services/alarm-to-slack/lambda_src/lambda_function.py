"""
Receives messages from CloudWatch alarms via SQS subscription to SNS.
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
    Validates it has AlarmName. Returns the parsed message or None.
    """
    try:
        body = json.loads(record['body'])
        message = json.loads(body['Message'])

        if 'AlarmName' not in message:
            log({'msg': 'AlarmName not found in message',
                 'messageId': record.get('messageId')})
            return None

        return message
    except json.JSONDecodeError:
        log({'msg': 'Did not receive an SNS CloudWatch payload',
             'messageId': record.get('messageId')})
    return None

def enriched_cloudwatch_message(record):
    """
    Parses the CloudWatch message, extracts the app and env from the alarm name,
    validates env is in dev|test|sandbox|prod, and enriches it with an emoji.
    """
    message = cloudwatch_message(record)
    if not message:
        return None

    alarm_name = message['AlarmName']
    parts = alarm_name.split('-')
    if len(parts) < 2:
        log({'msg': f'AlarmName "{alarm_name}" does not match expected format',
             'messageId': record.get('messageId')})
        return None

    message['App'] = parts[0]
    env = parts[1]

    if env not in ["dev", "test", "sandbox", "prod"]:
        log({'msg': f'Environment "{env}" in AlarmName "{alarm_name}" is not valid',
             'messageId': record.get('messageId')})
        return None

    message['Env'] = env

    log({'App': message['App'],
         'Env': message['Env'],
         'AlarmName': alarm_name,
         'NewStateValue': message.get('NewStateValue'),
         'OldStateValue': message.get('OldStateValue'),
         'StateChangeTime': message.get('StateChangeTime'),
         'msg': 'Received CloudWatch Alarm',
         'messageId': record.get('messageId')})

    if message['NewStateValue'] == 'OK' and is_ignore_ok():
        return None

    message['Emoji'] = ':checked:' if message['NewStateValue'] == 'OK' else ':anger:'
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
