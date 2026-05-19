"""
Receives messages from CloudWatch alarms via SQS subscription to SNS.
Forwards the alarms to Slack, with an emoji that says good or bad.
"""

from datetime import datetime, timezone
import json
import os
from urllib import request
from urllib.error import URLError, HTTPError
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


def ping_slack_webhook(webhook, app, message_id=None):
    """
    Sends a liveness ping to a Slack webhook using an empty payload.
    Slack returns 400 for empty payloads, but a 400 still confirms the
    webhook URL is reachable. A URLError or non-reachable host indicates
    a broken webhook.
    """
    try:
        jsondata = json.dumps({}).encode('utf-8')
        req = request.Request(webhook)
        req.add_header('Content-Type', 'application/json; charset=utf-8')
        req.add_header('Content-Length', str(len(jsondata)))
        with request.urlopen(req, jsondata) as resp:
            log({'msg': f'Liveness ping succeeded for app: {app}',
                 'status': resp.status, 'messageId': message_id})
            return True
    except HTTPError as e:
        # Slack returns 400 for empty payloads — still means the URL is reachable
        if e.code == 400:
            log({'msg': f'Liveness ping reachable (400 expected) for app: {app}',
                 'messageId': message_id})
            return True
        log({'msg': f'Liveness ping FAILED (HTTP {e.code}) for app: {app}',
             'messageId': message_id})
        return False
    except URLError as e:
        log({'msg': f'Liveness ping FAILED for app: {app}, reason: {e.reason}',
             'messageId': message_id})
        return False

def get_app_list():
    apps_env = os.environ.get('APPS', '')
    return [app.strip() for app in apps_env.split(',') if app.strip()]

def liveness_check():
    """
    Iterates over all configured apps (from the APPS env var), retrieves each
    app's Slack webhook SSM parameter, and performs a connectivity ping.

    Returns a dict with:
      - 'results': per-app status (ssm_ok, webhook_reachable)
      - 'all_ok': True only if every app passed both checks
    """
    apps = get_app_list()
    if not apps:
        log({'msg': 'Liveness check: No apps configured in APPS environment variable'})
        return {'results': {}, 'all_ok': True}

    results = {}
    all_ok = True
    ssm_env = os.environ.get('SSM_ENV', '').lower()
    for app in apps:
        param_name = f'/{app}/{ssm_env}/lambda/slack_webhook_url'
        webhook = get_ssm_parameter(param_name)

        ssm_ok = webhook is not None
        webhook_reachable = False

        if ssm_ok:
            webhook_reachable = ping_slack_webhook(webhook, app)
        else:
            log({'msg': f'Liveness check FAILED: SSM parameter missing or broken for app: {app}',
                 'param': param_name})

        app_ok = ssm_ok and webhook_reachable
        all_ok = all_ok and app_ok

        results[app] = {
            'ssm_ok': ssm_ok,
            'webhook_reachable': webhook_reachable,
            'ok': app_ok,
        }

        log({
            'msg': 'Liveness check result',
            'app': app,
            'ssm_ok': ssm_ok,
            'webhook_reachable': webhook_reachable,
            'ok': app_ok,
        })

    return {'results': results, 'all_ok': all_ok}

def handle_liveness_event(event):
    """
    Handles a deploy-time liveness check invocation from Tofu's aws_lambda_invocation.
    Raises RuntimeError if any app's SSM parameter or Slack webhook is unreachable,
    which surfaces as a function error and fails the Tofu apply.
    """
    check = liveness_check()

    log({
        'msg': 'Liveness check complete',
        'all_ok': check['all_ok'],
        'results': check['results'],
    })

    if not check['all_ok']:
        failed = [app for app, r in check['results'].items() if not r['ok']]
        raise RuntimeError(
            f"Liveness check failed for app(s): {', '.join(failed)}. "
            "Check CloudWatch logs for details."
        )

    return {
        'statusCode': 200,
        'body': 'Liveness check passed',
        'results': check['results'],
    }

def lambda_handler(event, _):
    """
    Main entry point for the Lambda function.
    Handles two event types:
    1) A liveness check that can be invoked via Tofu changes
    2) Primary function: Iteration through the SQS records, processes each CloudWatch alarm,
    and forwards it to the appropriate Slack channel.
    """

    if event.get('RequestType') == 'LivenessCheck':
        return handle_liveness_event(event)

    processed_count = 0
    ssm_env = os.environ.get('SSM_ENV', '').lower()

    for record in event['Records']:
        message = enriched_cloudwatch_message(record)
        if message:
            app = message.get('App')
            if app:
                webhook = get_ssm_parameter(f'/{app}/{ssm_env}/lambda/slack_webhook_url')
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
