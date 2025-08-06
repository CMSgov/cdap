"""
Unit tests for lambda_function.py that handle CloudWatch Alarm messages and Slack notifications.
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

@patch('lambda_function.boto3.client')
def setup_module(mock_boto_client):
    pass

def reload_lambda():
    import importlib
    import sys
    if 'lambda_function' in sys.modules:
        importlib.reload(sys.modules['lambda_function'])
    else:
        import lambda_function
    return sys.modules['lambda_function']

def test_cloudwatch_message_sqs_record():
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
    message = lambda_function.cloudwatch_message(non_cloudwatch_records)
    assert message is None

def test_enriched_cloudwatch_message_alarm_record():
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
    reload_lambda()
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
    reload_lambda()
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
    reload_lambda()
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
    message = lambda_function.enriched_cloudwatch_message(non_cloudwatch_records)
    assert message is None

@patch('lambda_function.log')
def test_enriched_cloudwatch_message_alarmname_does_not_match(mock_log):
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
    cm = MagicMock()
    cm.status = 200
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'happy path') is True

@patch('urllib.request.urlopen')
def test_send_message_to_slack_bad_resp(mock_urlopen):
    cm = MagicMock()
    cm.status = 404
    cm.__enter__.return_value = cm
    mock_urlopen.return_value = cm
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, '404 error') is False

@patch('urllib.request.urlopen')
def test_send_message_to_slack_url_error(mock_urlopen):
    mock_urlopen.side_effect = URLError('forced error')
    assert lambda_function.send_message_to_slack(
        'https://dpc.cms.gov', {'foo': 'bar'}, 'url error') is False

def test_send_message_to_slack_no_webhook():
    assert lambda_function.send_message_to_slack(None, {'foo': 'bar'}, 'no webhook') is False

@patch('lambda_function.get_ssm_parameter')
@patch('urllib.request.urlopen')
def test_handler(mock_urlopen, mock_get_ssm_parameter):
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
    lambda_function.log({'test': 'log'})
    captured = capsys.readouterr()
    log_output = json.loads(captured.out)
    assert log_output['test'] == 'log'
    assert 'time' in log_output
