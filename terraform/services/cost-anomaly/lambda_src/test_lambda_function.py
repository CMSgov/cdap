"""
Unit tests for lambda_function.py that handle cost_anomaly Alarm messages and Slack notifications.
"""

import json
import os
import importlib
import sys

from unittest.mock import patch, MagicMock
from urllib.error import URLError
import pytest

import lambda_function

NON_cost_anomaly_RECORDS = (
    {'messageId': 'raw sqs', 'body': 'SQS Raw text message'},
    {'messageId': 'raw sns', 'body': json.dumps({'Message': 'SNW Raw text message'})},
    {'messageId': 's3 event',
     'body': json.dumps({'Message': json.dumps({
         'Records': [{'EventName': 'ObjectCreated:Put', 's3': {}}]
     })})},
)

@pytest.fixture(autouse=True)
def mock_boto3_client():
    """Automatically mock boto3.client for all tests."""
    with patch('lambda_function.boto3.client') as mock_client:
        yield mock_client

def reload_lambda():
    """Reload the lambda_function module to pick up environment variable changes."""
    if 'lambda_function' in sys.modules:
        importlib.reload(sys.modules['lambda_function'])
    return sys.modules['lambda_function']

def test_cost_anomaly_message_sqs_record():
    """Test parsing a valid cost_anomaly message from an SQS record."""
    cost_anomaly_message = {
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK',
        'AlarmName': 'app-dev-alarm'
    }
    message = lambda_function.cost_anomaly_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message == cost_anomaly_message

@pytest.mark.parametrize("non_cost_anomaly_records", NON_cost_anomaly_RECORDS)
def test_cost_anomaly_message_non_cost_anomaly_records(non_cost_anomaly_records):
    """Test that non-cost_anomaly messages return None."""
    message = lambda_function.cost_anomaly_message(non_cost_anomaly_records)
    assert message is None

def test_enriched_cost_anomaly_message_alarm_record():
    """Test enrichment of a cost_anomaly alarm message."""
    cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM'
    }
    enriched_cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':anger:'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message == enriched_cost_anomaly_message

@patch.dict(os.environ, {'IGNORE_OK': 'false'}, clear=True)
def test_enriched_cost_anomaly_message_alarm_record_ok_ignored():
    """Test enrichment when IGNORE_OK is false and state is ALARM."""
    reload_lambda()
    cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM'
    }
    enriched_cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'OK',
        'NewStateValue': 'ALARM',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':anger:'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'Alarm',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message == enriched_cost_anomaly_message

def test_enriched_cost_anomaly_message_ok_record():
    """Test enrichment of OK state message when IGNORE_OK is false."""
    cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    enriched_cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':checked:'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'OK Sent',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message == enriched_cost_anomaly_message

@patch.dict(os.environ, {'IGNORE_OK': 'false'}, clear=True)
def test_enriched_cost_anomaly_message_ok_record_ignore_false():
    """Test OK state message with IGNORE_OK explicitly set to false."""
    reload_lambda()
    cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    enriched_cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK',
        'App': 'bcda',
        'Env': 'dev',
        'Emoji': ':checked:'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'OK Sent',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message == enriched_cost_anomaly_message

@patch.dict(os.environ, {'IGNORE_OK': 'true'}, clear=True)
def test_enriched_cost_anomaly_message_ok_record_ok_ignored():
    """Test that OK state message is ignored when IGNORE_OK is true."""
    reload_lambda()
    cost_anomaly_message = {
        'AlarmName': 'bcda-dev-SomeAlarm',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'OK Ignored',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message is None

@pytest.mark.parametrize("non_cost_anomaly_records", NON_cost_anomaly_RECORDS)
def test_enriched_cost_anomaly_message_non_cost_anomaly_records(non_cost_anomaly_records):
    """Test enrichment returns None for non-cost_anomaly messages."""
    message = lambda_function.enriched_cost_anomaly_message(non_cost_anomaly_records)
    assert message is None

@patch('lambda_function.log')
def test_enriched_cost_anomaly_message_alarmname_does_not_match(mock_log):
    """Test handling of AlarmName that does not match expected format."""
    cost_anomaly_message = {
        'AlarmName': 'invalidformat',
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'AlarmNameFail',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message is None

    mock_log.assert_called_once()
    log_args = mock_log.call_args[0][0]
    assert log_args['msg'] == 'AlarmName "invalidformat" does not match expected format'
    assert log_args['messageId'] == 'AlarmNameFail'

@patch('lambda_function.log')
def test_enriched_cost_anomaly_message_alarmname_not_found(mock_log):
    """Test handling of missing AlarmName in the message."""
    cost_anomaly_message = {
        'OldStateValue': 'ALARM',
        'NewStateValue': 'OK'
    }
    message = lambda_function.enriched_cost_anomaly_message({
        'messageId': 'MissingAlarmName',
        'body': json.dumps({'Message': json.dumps(cost_anomaly_message)})
    })
    assert message is None

    mock_log.assert_called_once()
    log_args = mock_log.call_args[0][0]
    assert log_args['msg'] == 'AlarmName not found in message'
    assert log_args['messageId'] == 'MissingAlarmName'

@patch('urllib.request.urlopen')
def test_send_message_to_slack_happy_path(mock_urlopen):
    """Test successful sending of message to Slack."""
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'Cost Anomaly Alert', {'foo': 'bar'}, 'happy path') is True

@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    """Test Slack sending failure due to bad HTTP response."""
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'Cost Anomaly Alert', {'foo': 'bar'}, '404 error') is False

@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    """Test Slack sending failure due to URL error."""
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack(
        'Cost Anomaly Alert', {'foo': 'bar'}, 'url error') is False

def test_send_message_to_slack_no_webhook():
    """Test sending Slack message with no webhook URL provided."""
    assert lambda_function.send_message_to_slack(None, {'foo': 'bar'}, 'no webhook') is False

@patch('lambda_function.get_ssm_parameter')
@patch('urllib.request.urlopen')
def test_handler(mock_urlopen, mock_get_ssm_parameter):
    """Test full lambda_handler with mocked SSM and Slack send."""
    mock_get_ssm_parameter.return_value = 'Cost Anomaly Alert'
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm

    sqs_message = {'Records': [{
        'messageId': 'full test',
        'body': json.dumps({'Message': json.dumps({
            'AlarmName': 'dev-cost_anomaly-alarms',
            'OldStateValue': 'OK',
            'NewStateValue': 'ALARM'
        })})
    }]}

    response = lambda_function.lambda_handler(sqs_message, None)
    assert response['body'] == 'Processed 1 messages successfully'

def test_logger(capsys):
    """Test that logging outputs JSON with a time field."""
    lambda_function.log({'test': 'log'})
    captured = capsys.readouterr()
    log_output = json.loads(captured.out)
    assert log_output['test'] == 'log'
    assert 'time' in log_output
