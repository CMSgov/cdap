"""
Unit tests for the alarm-to-slack Lambda.
"""

import json
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

import pytest
from botocore.exceptions import ClientError

import lambda_function

# pytest fixtures are referenced by parameter name, which pylint flags as redefining outer scope
# pylint: disable=redefined-outer-name


@pytest.fixture(autouse=True)
def reset_ssm_cache():
    """
    ssm_parameter_cache is a module-level dict, so it persists across tests
    unless explicitly cleared. Without this, tests can see stale cached
    values from earlier tests instead of hitting their own mocks.
    """
    lambda_function.ssm_parameter_cache.clear()
    yield
    lambda_function.ssm_parameter_cache.clear()


def _make_sqs_record(message_body, message_id='msg-1'):
    """Builds an SQS record wrapping an SNS-style CloudWatch alarm body."""
    return {
        'messageId': message_id,
        'body': json.dumps({'Message': json.dumps(message_body)}),
    }


def _make_urlopen_response(status=200):
    """Builds a context-manager mock resembling urllib's response object."""
    mock_resp = MagicMock()
    mock_resp.status = status
    mock_cm = MagicMock()
    mock_cm.__enter__.return_value = mock_resp
    mock_cm.__exit__.return_value = False
    return mock_cm


def test_get_ssm_parameter_caches_value():
    """A successful lookup is cached so subsequent calls don't re-hit SSM."""
    mock_ssm = MagicMock()
    mock_ssm.get_parameter.return_value = {'Parameter': {'Value': 'https://hooks.slack.com/abc'}}
    with patch('lambda_function.get_ssm_client', return_value=mock_ssm):
        first = lambda_function.get_ssm_parameter('/app/test/lambda/slack_webhook_url')
        second = lambda_function.get_ssm_parameter('/app/test/lambda/slack_webhook_url')
    assert first == 'https://hooks.slack.com/abc'
    assert second == 'https://hooks.slack.com/abc'
    mock_ssm.get_parameter.assert_called_once()


def test_get_ssm_parameter_caches_none_on_error(capfd):
    """A ClientError is logged and None is cached, not retried on next call."""
    mock_ssm = MagicMock()
    mock_ssm.get_parameter.side_effect = ClientError({}, 'GetParameter')
    with patch('lambda_function.get_ssm_client', return_value=mock_ssm):
        first = lambda_function.get_ssm_parameter('/app/test/lambda/slack_webhook_url')
        second = lambda_function.get_ssm_parameter('/app/test/lambda/slack_webhook_url')
    assert first is None
    assert second is None
    mock_ssm.get_parameter.assert_called_once()
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'Error getting SSM parameter' in log_line['msg']


@pytest.mark.parametrize("env_value,expected", [
    ('true', True),
    ('True', True),
    ('false', False),
    (None, False),
])
def test_is_ignore_ok(monkeypatch, env_value, expected):
    """IGNORE_OK is case-insensitive and defaults to False when unset."""
    if env_value is None:
        monkeypatch.delenv('IGNORE_OK', raising=False)
    else:
        monkeypatch.setenv('IGNORE_OK', env_value)
    assert lambda_function.is_ignore_ok() == expected


@pytest.mark.parametrize("apps_env,expected", [
    ('dpc,bcda,ab2d', ['dpc', 'bcda', 'ab2d']),
    ('dpc, bcda , ab2d', ['dpc', 'bcda', 'ab2d']),
    ('', []),
    ('dpc,,bcda', ['dpc', 'bcda']),
])
def test_get_app_list(monkeypatch, apps_env, expected):
    """APPS env var is parsed into a clean, trimmed list."""
    monkeypatch.setenv('APPS', apps_env)
    assert lambda_function.get_app_list() == expected


def test_ping_slack_webhook_success():
    """A 200 response counts as a successful liveness ping."""
    with patch('lambda_function.request.urlopen', return_value=_make_urlopen_response(200)):
        assert lambda_function.ping_slack_webhook('https://hooks.slack.com/x', 'dpc') is True


def test_ping_slack_webhook_400_counts_as_reachable():
    """Slack returns 400 for an empty payload — that still proves the URL is reachable."""
    error = HTTPError('https://hooks.slack.com/x', 400, 'Bad Request', {}, None)
    with patch('lambda_function.request.urlopen', side_effect=error):
        assert lambda_function.ping_slack_webhook('https://hooks.slack.com/x', 'dpc') is True


def test_ping_slack_webhook_other_http_error_fails():
    """A non-400 HTTP error is treated as a genuine failure."""
    error = HTTPError('https://hooks.slack.com/x', 500, 'Server Error', {}, None)
    with patch('lambda_function.request.urlopen', side_effect=error):
        assert lambda_function.ping_slack_webhook('https://hooks.slack.com/x', 'dpc') is False


def test_ping_slack_webhook_url_error_fails():
    """An unreachable host (URLError) is treated as a failure."""
    with patch('lambda_function.request.urlopen', side_effect=URLError('no route to host')):
        assert lambda_function.ping_slack_webhook('https://hooks.slack.com/x', 'dpc') is False


def test_liveness_check_no_apps_configured(monkeypatch, capfd):
    """No APPS configured is treated as a trivially passing check, not a failure."""
    monkeypatch.setenv('APPS', '')
    result = lambda_function.liveness_check()
    assert result == {'results': {}, 'all_ok': True}
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'No apps configured' in log_line['msg']


def test_liveness_check_all_apps_healthy(monkeypatch):
    """Every app with a valid SSM param and reachable webhook reports all_ok=True."""
    monkeypatch.setenv('APPS', 'dpc,bcda')
    monkeypatch.setenv('SSM_ENV', 'test')
    with patch('lambda_function.get_ssm_parameter', return_value='https://hooks.slack.com/x'), \
         patch('lambda_function.ping_slack_webhook', return_value=True):
        result = lambda_function.liveness_check()
    assert result['all_ok'] is True
    assert result['results']['dpc']['ok'] is True
    assert result['results']['bcda']['ok'] is True


def test_liveness_check_missing_ssm_param_fails_that_app(monkeypatch):
    """An app with no SSM parameter fails, without a webhook ping ever being attempted."""
    monkeypatch.setenv('APPS', 'dpc')
    monkeypatch.setenv('SSM_ENV', 'test')
    with patch('lambda_function.get_ssm_parameter', return_value=None), \
         patch('lambda_function.ping_slack_webhook') as mock_ping:
        result = lambda_function.liveness_check()
    assert result['all_ok'] is False
    assert result['results']['dpc']['ssm_ok'] is False
    mock_ping.assert_not_called()


def test_liveness_check_unreachable_webhook_fails_that_app(monkeypatch):
    """A valid SSM param but unreachable webhook still fails the app overall."""
    monkeypatch.setenv('APPS', 'dpc')
    monkeypatch.setenv('SSM_ENV', 'test')
    with patch('lambda_function.get_ssm_parameter', return_value='https://hooks.slack.com/x'), \
         patch('lambda_function.ping_slack_webhook', return_value=False):
        result = lambda_function.liveness_check()
    assert result['all_ok'] is False
    assert result['results']['dpc']['webhook_reachable'] is False


def test_handle_liveness_event_raises_on_failure():
    """A failed liveness check raises so the deploy-time invocation fails loudly."""
    with patch('lambda_function.liveness_check', return_value={
        'all_ok': False,
        'results': {'dpc': {'ok': False, 'ssm_ok': False, 'webhook_reachable': False}},
    }):
        with pytest.raises(RuntimeError, match='dpc'):
            lambda_function.handle_liveness_event({})


def test_handle_liveness_event_returns_200_on_success():
    """A fully healthy liveness check returns a 200 payload rather than raising."""
    with patch('lambda_function.liveness_check', return_value={
        'all_ok': True,
        'results': {'dpc': {'ok': True, 'ssm_ok': True, 'webhook_reachable': True}},
    }):
        result = lambda_function.handle_liveness_event({})
    assert result['statusCode'] == 200


def test_cloudwatch_message_valid():
    """A well-formed SNS/CloudWatch payload is parsed into a dict."""
    record = _make_sqs_record({'AlarmName': 'dpc-test-high-cpu', 'NewStateValue': 'ALARM'})
    result = lambda_function.cloudwatch_message(record)
    assert result['AlarmName'] == 'dpc-test-high-cpu'


def test_cloudwatch_message_missing_alarm_name(capfd):
    """A message without AlarmName is rejected and logged, not raised."""
    record = _make_sqs_record({'NewStateValue': 'ALARM'})
    assert lambda_function.cloudwatch_message(record) is None
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'AlarmName not found' in log_line['msg']


def test_cloudwatch_message_malformed_json(capfd):
    """A body that isn't valid JSON is rejected and logged, not raised."""
    record = {'messageId': 'msg-1', 'body': 'not json'}
    assert lambda_function.cloudwatch_message(record) is None
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'Did not receive an SNS CloudWatch payload' in log_line['msg']


@pytest.mark.parametrize("alarm_name,expected_app,expected_env", [
    ('dpc-test-high-cpu', 'dpc', 'test'),
    ('bcda-prod-low-disk', 'bcda', 'prod'),
])
def test_enriched_cloudwatch_message_parses_app_and_env(alarm_name, expected_app, expected_env):
    """App and Env are correctly extracted from a valid AlarmName."""
    record = _make_sqs_record({'AlarmName': alarm_name, 'NewStateValue': 'ALARM'})
    result = lambda_function.enriched_cloudwatch_message(record)
    assert result['App'] == expected_app
    assert result['Env'] == expected_env


def test_enriched_cloudwatch_message_rejects_invalid_env(capfd):
    """An AlarmName with an unrecognized environment segment is rejected."""
    record = _make_sqs_record({'AlarmName': 'dpc-staging-high-cpu', 'NewStateValue': 'ALARM'})
    assert lambda_function.enriched_cloudwatch_message(record) is None
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'is not valid' in log_line['msg']


def test_enriched_cloudwatch_message_rejects_short_alarm_name(capfd):
    """An AlarmName without at least an app and env segment is rejected."""
    record = _make_sqs_record({'AlarmName': 'onlyoneword', 'NewStateValue': 'ALARM'})
    assert lambda_function.enriched_cloudwatch_message(record) is None
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'does not match expected format' in log_line['msg']


@pytest.mark.parametrize("new_state,expected_emoji", [
    ('ALARM', ':anger:'),
    ('OK', ':checked:'),
])
def test_enriched_cloudwatch_message_emoji(monkeypatch, new_state, expected_emoji):
    """ALARM and OK states get their respective emoji when IGNORE_OK is off."""
    monkeypatch.setenv('IGNORE_OK', 'false')
    record = _make_sqs_record({'AlarmName': 'dpc-test-high-cpu', 'NewStateValue': new_state})
    result = lambda_function.enriched_cloudwatch_message(record)
    assert result['Emoji'] == expected_emoji


def test_enriched_cloudwatch_message_suppresses_ok_when_ignored(monkeypatch):
    """An OK-state alarm is suppressed entirely when IGNORE_OK is true."""
    monkeypatch.setenv('IGNORE_OK', 'true')
    record = _make_sqs_record({'AlarmName': 'dpc-test-high-cpu', 'NewStateValue': 'OK'})
    assert lambda_function.enriched_cloudwatch_message(record) is None


def test_send_message_to_slack_success():
    """A 200 response from the webhook counts as a successful send."""
    with patch('lambda_function.request.urlopen', return_value=_make_urlopen_response(200)):
        assert lambda_function.send_message_to_slack(
            'https://hooks.slack.com/x', {'AlarmName': 'x'}, 'msg-1'
        ) is True


def test_send_message_to_slack_non_200_fails(capfd):
    """A non-200 response is logged and treated as a failed send."""
    with patch('lambda_function.request.urlopen', return_value=_make_urlopen_response(500)):
        result = lambda_function.send_message_to_slack(
            'https://hooks.slack.com/x', {'AlarmName': 'x'}, 'msg-1'
        )
    assert result is False
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'Unsuccessful attempt' in log_line['msg']


def test_send_message_to_slack_url_error_fails():
    """A URLError (unreachable webhook) is treated as a failed send, not raised."""
    with patch('lambda_function.request.urlopen', side_effect=URLError('unreachable')):
        result = lambda_function.send_message_to_slack(
            'https://hooks.slack.com/x', {'AlarmName': 'x'}, 'msg-1'
        )
    assert result is False


def test_send_message_to_slack_missing_webhook(capfd):
    """A falsy webhook short-circuits before attempting a network call."""
    result = lambda_function.send_message_to_slack(None, {'AlarmName': 'x'}, 'msg-1')
    assert result is False
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'webhook URL is not set' in log_line['msg']


def test_lambda_handler_dispatches_liveness_check():
    """A LivenessCheck event routes to handle_liveness_event, not the SQS path."""
    with patch('lambda_function.handle_liveness_event', return_value={'statusCode': 200}) as mock_handle:
        result = lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)
    mock_handle.assert_called_once()
    assert result == {'statusCode': 200}


def test_lambda_handler_processes_valid_alarm(monkeypatch):
    """A valid alarm record is enriched, sent to Slack, and counted as processed."""
    monkeypatch.setenv('SSM_ENV', 'test')
    record = _make_sqs_record({'AlarmName': 'dpc-test-high-cpu', 'NewStateValue': 'ALARM'})
    with patch('lambda_function.get_ssm_parameter', return_value='https://hooks.slack.com/x'), \
         patch('lambda_function.send_message_to_slack', return_value=True) as mock_send:
        result = lambda_function.lambda_handler({'Records': [record]}, None)
    mock_send.assert_called_once()
    assert result['body'] == 'Processed 1 messages successfully'


def test_lambda_handler_skips_record_with_no_webhook_configured(monkeypatch, capfd):
    """A valid alarm for an app with no configured webhook is skipped, not sent."""
    monkeypatch.setenv('SSM_ENV', 'test')
    record = _make_sqs_record({'AlarmName': 'dpc-test-high-cpu', 'NewStateValue': 'ALARM'})
    with patch('lambda_function.get_ssm_parameter', return_value=None), \
         patch('lambda_function.send_message_to_slack') as mock_send:
        result = lambda_function.lambda_handler({'Records': [record]}, None)
    mock_send.assert_not_called()
    assert result['body'] == 'Processed 0 messages successfully'
    log_line = json.loads(capfd.readouterr().out.strip().splitlines()[-1])
    assert 'Could not find Slack webhook' in log_line['msg']


def test_lambda_handler_skips_invalid_record(monkeypatch):
    """A record that fails enrichment (e.g. bad AlarmName) is skipped, not counted."""
    monkeypatch.setenv('SSM_ENV', 'test')
    record = _make_sqs_record({'AlarmName': 'onlyoneword', 'NewStateValue': 'ALARM'})
    with patch('lambda_function.send_message_to_slack') as mock_send:
        result = lambda_function.lambda_handler({'Records': [record]}, None)
    mock_send.assert_not_called()
    assert result['body'] == 'Processed 0 messages successfully'
