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
     'body': json.dumps({'Message':
                         json.dumps({'Records': [{'EventName': 'ObjectCreated:Put', 's3': {}}]})})},
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
    """Tests happy path of retrieving CloudWatch Message from SQS record."""
    cloudwatch_message = {'OldStateValue': 'ALARM', 'NewStateValue': 'OK'}
    message = lambda_function.cloudwatch_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message == cloudwatch_message

@pytest.mark.parametrize("non_cloudwatch_records", NON_CLOUDWATCH_RECORDS)
def test_cloudwatch_message_non_cloudwatch_records(non_cloudwatch_records):
    """Tests message when SQS record is not from a CloudWatch Alarm."""
    message = lambda_function.cloudwatch_message(non_cloudwatch_records)
    assert message is None

@patch.dict(os.environ, {'IGNORE_OK_APPS': ''}, clear=True)
def test_enriched_cloudwatch_message_alarm_record():
    """Tests happy path of enriching CloudWatch ALARM Message from SQS record."""
    lambda_function.initialize_ignore_ok_list()
    cloudwatch_message = {'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'AlarmName': 'dpc-prod-cloudwatch-alarms'}
    enriched_cloudwatch_message = {
        'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'AlarmName': 'dpc-prod-cloudwatch-alarms',
        'App': 'dpc', 'Env': 'prod', 'Emoji': ':anger:'}
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'Alarm', 'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message == enriched_cloudwatch_message

@patch.dict(os.environ, {'IGNORE_OK_APPS': 'dpc'}, clear=True)
def test_enriched_cloudwatch_message_ok_record_ignored():
    """Tests enriching a CloudWatch OK Message when IGNORE_OK is true for the app."""
    lambda_function.initialize_ignore_ok_list()
    cloudwatch_message = {'OldStateValue': 'ALARM', 'NewStateValue': 'OK', 'AlarmName': 'dpc-prod-cloudwatch-alarms'}
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Ignored', 'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message is None

@patch.dict(os.environ, {'IGNORE_OK_APPS': 'ab2d'}, clear=True)
def test_enriched_cloudwatch_message_ok_record_not_ignored():
    """Tests enriching a CloudWatch OK Message for an app not in the ignore list."""
    lambda_function.initialize_ignore_ok_list()
    cloudwatch_message = {'OldStateValue': 'ALARM', 'NewStateValue': 'OK', 'AlarmName': 'dpc-prod-cloudwatch-alarms'}
    enriched_cloudwatch_message = {
        'OldStateValue': 'ALARM', 'NewStateValue': 'OK', 'AlarmName': 'dpc-prod-cloudwatch-alarms',
        'App': 'dpc', 'Env': 'prod', 'Emoji': ':checked:'}
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Sent', 'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message == enriched_cloudwatch_message

def test_enriched_cloudwatch_message_bad_alarm_name():
    """Tests when the AlarmName does not match the expected format."""
    cloudwatch_message = {'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'AlarmName': 'malformed_alarm'}
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'Alarm', 'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message is None

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_happy_path(mock_urlopen):
    """Test happy path of sending a message to Slack."""
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, 'test', 'happy path') is True

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    """Test sending a message to Slack when 404 response."""
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, 'test', '404 error') is False

@patch.dict(os.environ, {'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov'}, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    """Test sending a message to Slack when URLError."""
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, 'test', 'url error') is False

def test_send_message_to_slack_no_webhook():
    """Test sending a message to Slack when webhook is not set."""
    assert lambda_function.send_message_to_slack('', 'not a dictionary', 'no webhook') is False

@patch('urllib.request.urlopen')
@mock_aws
@patch.dict(os.environ, {'IGNORE_OK_APPS': 'dpc'}, clear=True)
def test_handler(mock_urlopen):
    """Tests happy path of calling lambda_handler."""
    ssm = boto3.client("ssm", region_name="us-east-1")
    ssm.put_parameter(Name="/dpc/lambda/slack_webhook_url", Value="https://mock-dpc-webhook-url", Type="SecureString")
    
    lambda_function.ssm_parameter_cache = {}
    lambda_function.initialize_ignore_ok_list()
    sqs_message = {'Records': [{
        'messageId': 'full test',
        'body': json.dumps({'Message': json.dumps({'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'AlarmName': 'dpc-prod-cloudwatch-alarms'})})}]}
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
    """Makes sure log does not throw errors."""
    lambda_function.log({})
