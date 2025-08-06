"""
pytest of lambda_function.py
"""

import json
import os
from unittest.mock import patch, MagicMock
from urllib.error import URLError

from importlib import reload
import pytest

import lambda_function

NON_CLOUDWATCH_RECORDS = (
    {'messageId': 'raw sqs', 'body': 'SQS Raw text message'},
    {'messageId': 'raw sns', 'body': json.dumps({'Message': 'SNW Raw text message'})},
    {'messageId': 's3 event',
     'body': json.dumps({'Message': json.dumps({
         'Records': [{'EventName': 'ObjectCreated:Put', 's3': {}}]
     })})},
)

def test_cloudwatch_message_sqs_record():
    """Test happy path of retrieving CloudWatch Message from SQS record."""
    cloudwatch_message = {'OldStateValue': 'ALARM',
                        'NewStateValue': 'OK',
                        'AlarmName': 'app-dev-alarm'}
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

def test_enriched_cloudwatch_message_alarm_record():
    """Test enriching CloudWatch Alarm Message from SQS record (happy path)."""
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

@patch.dict(os.environ, {'IGNORE_OK': 'false'}, clear=True)
def test_enriched_cloudwatch_message_alarm_record_ok_ignored():
    """Test enrichment when IGNORE_OK is false, alarm state ALARM."""
    reload(lambda_function)
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
    reload(lambda_function)
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

@patch.dict(os.environ, {'IGNORE_OK': 'true'}, clear=True)
def test_enriched_cloudwatch_message_ok_record_ok_ignored():
    """Test enrichment ignores OK state when IGNORE_OK is globally true."""
    reload(lambda_function)
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

@patch('lambda_function.log')
def test_enriched_cloudwatch_message_alarmname_does_not_match(mock_log):
    """Test enrichment when AlarmName does not match expected format."""
    cloudwatch_message = {
        'AlarmName': 'invalidformat',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'AlarmNameFail',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message is None

    mock_log.assert_called_once()
    log_args = mock_log.call_args[0][0]
    assert log_args['msg'] == 'AlarmName "invalidformat" does not match expected format'
    assert log_args['messageId'] == 'AlarmNameFail'

@patch('lambda_function.log')
def test_enriched_cloudwatch_message_alarmname_not_found(mock_log):
    """Test enrichment when AlarmName is missing from the message."""
    cloudwatch_message = {
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cloudwatch_message({
        'messageId': 'MissingAlarmName',
        'body': json.dumps({'Message': json.dumps(cloudwatch_message)})
    })
    assert message is None

    mock_log.assert_called_once()
    log_args = mock_log.call_args[0][0]
    assert log_args['msg'] == 'AlarmName not found in message'
    assert log_args['messageId'] == 'MissingAlarmName'

@patch('urllib.request.urlopen')
def test_send_message_to_slack_happy_path(mock_urlopen):
    """Test sending message to Slack with a 200 response."""
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'happy path') is True

@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    """Test sending message to Slack with a non-200 response."""
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, '404 error') is False

@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    """Test sending message to Slack raises URLError."""
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'url error') is False

def test_send_message_to_slack_no_webhook():
    """Test sending message to Slack with no webhook URL."""
    assert lambda_function.send_message_to_slack(None, {'foo': 'bar'}, 'no webhook') is False

@patch('lambda_function.get_ssm_parameter')
@patch('urllib.request.urlopen')
def test_handler(mock_urlopen, mock_get_ssm_parameter):
    """Test the lambda_handler processes one SQS record correctly."""
    mock_get_ssm_parameter.return_value = 'https://dpc.cms.gov'
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm

    sqs_message = {'Records': [{
        'messageId': 'full test',
        'body': json.dumps({'Message': json.dumps({
            'AlarmName': 'dpc-dev-cloudwatch-alarms',
            'OldStateValue': 'OK',
            'NewStateValue': 'ALARM'
        })})
    }]}

    response = lambda_function.lambda_handler(sqs_message, None)
    assert response['body'] == 'Processed 1 messages successfully'

def test_logger(capsys):
    """Test that logger outputs JSON-formatted logs."""
    lambda_function.log({'test': 'log'})
    captured = capsys.readouterr()
    log_output = json.loads(captured.out)
    assert log_output['test'] == 'log'
    assert 'time' in log_output
