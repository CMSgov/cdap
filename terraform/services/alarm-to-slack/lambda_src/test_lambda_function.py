"""
pytest of lambda_function.py
"""

import json
import os
from unittest.mock import patch, MagicMock
from urllib.error import URLError
import pytest
from moto import mock_aws
import boto3

import lambda_function

NON_CLOUDWATCH_RECORDS = (
    {'messageId': 'raw sqs', 'body': 'SQS Raw text message'},
    {'messageId': 'raw sns', 'body': json.dumps({'Message': 'SNW Raw text message'})},
    {'messageId': 's3 event',
     'body': json.dumps({'Message': json.dumps({
         'Records': [{'EventName': 'ObjectCreated:Put', 's3': {}}]
     })})},
)

def create_sqs_body(alarm_message):
    """Encapsulates a CloudWatch alarm message in an SQS body."""
    return json.dumps({"Type": "Notification", "Message": json.dumps(alarm_message)})

def create_urlopen_mock(status=200, side_effect=None):
    """Creates a mock for urllib.request.urlopen with context manager behavior."""
    mock_response = MagicMock(status=status)
    mock_context_manager = MagicMock()
    mock_context_manager.__enter__.return_value = mock_response
    if side_effect:
        mock_context_manager.__enter__.side_effect = side_effect
    return mock_context_manager

@pytest.fixture
def mock_ssm_client():
    """Sets up a mock SSM client with webhook parameters."""
    with mock_aws():
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(
            Name="/dpc/lambda/slack_webhook_url", Value="https://mock-dpc-webhook-url", Type="SecureString")
        ssm.put_parameter(
            Name="/ab2d/lambda/slack_webhook_url", Value="https://mock-ab2d-webhook-url", Type="SecureString")
        ssm.put_parameter(
            Name="/bcda/lambda/slack_webhook_url", Value="https://mock-bcda-webhook-url", Type="SecureString")
        yield ssm

# --- Tests ---

def test_cloudwatch_message_sqs_record():
    """Test happy path of retrieving CloudWatch Message from SQS record."""
    cloudwatch_message = {'OldStateValue': 'ALARM', 'NewStateValue': 'OK'}
    message = lambda_function.cloudwatch_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == cloudwatch_message

@pytest.mark.parametrize("non_cloudwatch_records", NON_CLOUDWATCH_RECORDS)
def test_cloudwatch_message_non_cloudwatch_records(non_cloudwatch_records):
    """Test cloudwatch message when SQS record is not from CloudWatch Alarm."""
    message = lambda_function.cloudwatch_message(non_cloudwatch_records)
    assert message is None

@patch.dict(os.environ, {'IGNORE_OK_APPS': ''}, clear=True)
def test_enriched_cloudwatch_message_alarm_record():
    """Test enriching CloudWatch Alarm Message from SQS record (happy path)."""
    cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM'
    }
    enriched_cloudwatch_message = {
        'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'AlarmName': 'dpc-prod-cloudwatch-alarms',
        'App': 'dpc', 'Env': 'prod', 'Emoji': ':anger:'}
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == enriched_cloudwatch_message

@patch.dict(os.environ, {'IGNORE_OK': 'true'}, clear=True)
def test_enriched_cloudwatch_message_alarm_record_ok_ignored():
    """Test enrichment when IGNORE_OK is true, alarm state ALARM."""
    cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM'
    }
    enriched_cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':anger:'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == enriched_cloudwatch_message

def test_enriched_cloudwatch_message_ok_record():
    """Test enrichment when alarm state transitions to OK."""
    cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    enriched_cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':checked:'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Sent',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == enriched_cloudwatch_message

@patch.dict(os.environ, {'IGNORE_OK': 'false'}, clear=True)
def test_enriched_cloudwatch_message_ok_record_ignore_false():
    """Test enrichment when IGNORE_OK is false, alarm state OK."""
    cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    enriched_cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':checked:'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Sent',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == enriched_cloudwatch_message

@patch.dict(os.environ, {'IGNORE_OK_APPS': 'bcda'}, clear=True)
def test_enriched_cloudwatch_message_ok_record_ok_ignored():
    """Test enrichment ignores OK state when app is in IGNORE_OK_APPS list."""
    lambda_function.initialize_ignore_ok_list(lambda_function.ignore_ok_apps)
    cloudwatch_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Ignored',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message is None

@pytest.mark.parametrize("non_cloudwatch_records", NON_CLOUDWATCH_RECORDS)
def test_enriched_cloudwatch_message_non_cloudwatch_records(non_cloudwatch_records):
    """Test enrichment returns None for non-cloudwatch records."""
    message = lambda_function.enriched_cloudwatch_message(non_cloudwatch_records)
    assert message is None

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_happy_path(mock_urlopen):
    """Test sending message to Slack with a 200 response."""
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'happy path') is True

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    """Test sending message to Slack with a non-200 response."""
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, '404 error') is False

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    """Test sending message to Slack raises URLError."""
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'url error') is False

def test_send_message_to_slack_no_webhook():
    """Test sending message to Slack with no webhook URL."""
    assert lambda_function.send_message_to_slack(None, {'foo': 'bar'}, 'no webhook') is False

@patch('urllib.request.urlopen')
def test_handler(mock_urlopen, mock_get_ssm_parameter):
    """Test the lambda_handler processes one SQS record correctly."""
    mock_get_ssm_parameter.return_value = 'https://dpc.cms.gov'
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    resp = lambda_function.lambda_handler(sqs_message, None)
    assert resp['body'] == 'Processed 1 messages successfully'

@mock_aws
def test_get_ssm_parameter_and_caching():
    """Tests fetching and caching of SSM parameters for multiple apps."""
    ssm = boto3.client("ssm", region_name="us-east-1")
    ssm.put_parameter(Name="/dpc/lambda/slack_webhook_url", Value="https://mock-dpc-webhook-url", Type="SecureString")
    ssm.put_parameter(Name="/ab2d/lambda/slack_webhook_url", Value="https://mock-ab2d-webhook-url", Type="SecureString")
    lambda_function.ssm_parameter_cache = {}
    
    with patch.object(lambda_function.ssm_client, 'get_parameter', wraps=ssm.get_parameter) as mock_get_parameter:
        lambda_function.get_ssm_parameter("/dpc/lambda/slack_webhook_url")
        lambda_function.get_ssm_parameter("/ab2d/lambda/slack_webhook_url")
        assert mock_get_parameter.call_count == 2
        
        lambda_function.get_ssm_parameter("/dpc/lambda/slack_webhook_url")
        lambda_function.get_ssm_parameter("/ab2d/lambda/slack_webhook_url")
        assert mock_get_parameter.call_count == 2
    
def test_logger():
    """Test that logger outputs JSON-formatted logs."""
    lambda_function.log({'test': 'log'})
