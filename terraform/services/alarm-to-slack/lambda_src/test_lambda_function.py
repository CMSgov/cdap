import json
import os
from unittest.mock import patch, MagicMock
from urllib.error import URLError

import pytest

import lambda_function

NON_CLOUDWATCH_RECORDS = (
    {'messageId': 'raw sqs', 'body': 'SQS Raw text message'},
    {'messageId': 'raw sns', 'body': json.dumps({'Message': 'SNW Raw text message'})},
    {'messageId': 's3 event',
     'body': json.dumps({'Message': json.dumps({'Records': [{ 'EventName': 'ObjectCreated:Put', 's3': {}}]})})},
)

def test_cloudwatch_message_sqs_record():
    cloudwatch_message = { 'OldStateValue': 'ALARM', 'NewStateValue': 'OK' }
    message = lambda_function.cloudwatch_message({'messageId': 'Alarm',
                                                  'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message == cloudwatch_message

@pytest.mark.parametrize("non_cloudwatch_records", NON_CLOUDWATCH_RECORDS)
def test_cloudwatch_message_non_cloudwatch_records(non_cloudwatch_records):
    message = lambda_function.cloudwatch_message(non_cloudwatch_records)
    assert message is None

def test_enriched_cloudwatch_message_alarm_record():
    cloudwatch_message = { 'OldStateValue': 'OK', 'NewStateValue': 'ALARM' }
    enriched_cloudwatch_message = { 'OldStateValue': 'OK', 'NewStateValue': 'ALARM', 'Emoji': ':anger:' }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message == enriched_cloudwatch_message

def test_enriched_cloudwatch_message_ok_record():
    cloudwatch_message = { 'OldStateValue': 'ALARM', 'NewStateValue': 'OK' }
    enriched_cloudwatch_message = cloudwatch_message.copy()
    enriched_cloudwatch_message['Emoji'] = ':checked:'
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Sent',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message == enriched_cloudwatch_message

@patch.dict(os.environ, { 'IGNORE_OK': 'true' }, clear=True)
def test_enriched_cloudwatch_message_ok_record_ok_ignored():
    cloudwatch_message = { 'OldStateValue': 'ALARM', 'NewStateValue': 'OK' }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'OK Ignored',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})})
    assert message is None

@pytest.mark.parametrize("non_cloudwatch_records", NON_CLOUDWATCH_RECORDS)
def test_enriched_cloudwatch_message_non_cloudwatch_records(non_cloudwatch_records):
    message = lambda_function.enriched_cloudwatch_message(non_cloudwatch_records)
    assert message is None

@patch.dict(os.environ, { 'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov' }, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_happy_path(mock_urlopen):
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, 'happy path') is True

@patch.dict(os.environ, { 'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov' }, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, '404 error') is False

@patch.dict(os.environ, { 'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov' }, clear=True)
@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack({'foo': 'bar'}, 'url error') is False

def test_send_message_to_slack_no_webhook():
    assert lambda_function.send_message_to_slack('not a dictionary', 'no webhook') is False

@patch.dict(os.environ, { 'SLACK_WEBHOOK_URL': 'https://dpc.cms.gov' }, clear=True)
@patch('urllib.request.urlopen')
def test_handler(mock_urlopen):
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    sqs_message = {'Records': [{
        'messageId': 'full test',
        'body':json.dumps({ 'Message': json.dumps({ 'OldStateValue': 'OK', 'NewStateValue': 'ALARM' })})}]}
    resp = lambda_function.lambda_handler(sqs_message, None)
    assert resp['body'] == 'Processed 1 messages'

def test_logger():
    lambda_function.log({})
