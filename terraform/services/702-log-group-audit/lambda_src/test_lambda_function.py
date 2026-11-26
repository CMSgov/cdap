"""
Unit tests for the log group audit Lambda. All AWS calls are mocked, so no
credentials required.
"""

import json
import os
from unittest.mock import MagicMock, patch

import pytest

import lambda_function


FIREHOSE_ARN = 'arn:aws:firehose:us-east-1:123456789012:deliverystream/shared-test-log-retention'
TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789012:cdap-test-cdap-alarms'
BASE_ENV = {
    'ENV': 'test',
    'RESULTS_BUCKET': 'cdap-test-log-group-audit',
    'RESULTS_PREFIX': 'results/',
    'SNS_TOPIC_ARN': TOPIC_ARN,
    'FIREHOSE_ARN_SSM_PARAM': '/cdap/test/common/nonsensitive/log-retention/firehose-arn',
    'EXCEPTIONS': json.dumps(['/aws/kinesisfirehose/shared-test-log-retention']),
    'EXCEPTION_PREFIXES': json.dumps(['cms-cloud-', '/aws/ec2/var/']),
    'AWS_REGION': 'us-east-1',
}


@pytest.fixture(autouse=True)
def clear_caches():
    lambda_function.client_cache.clear()
    lambda_function.ssm_parameter_cache.clear()
    yield
    lambda_function.client_cache.clear()
    lambda_function.ssm_parameter_cache.clear()


@pytest.fixture(autouse=True)
def env_vars():
    with patch.dict(os.environ, BASE_ENV):
        yield


def log_group_arn(name):
    return f'arn:aws:logs:us-east-1:123456789012:log-group:{name}'


def make_clients(log_groups, tagged_names, routed_names):
    """
    Builds a dict of mocked boto3 clients representing an account with the
    given log groups, of which tagged_names carry terraform=true and
    routed_names have a subscription filter to the Firehose.
    """
    logs = MagicMock()
    logs.get_paginator.return_value.paginate.return_value = [
        {'logGroups': [{'logGroupName': n, 'retentionInDays': 180} for n in log_groups]}
    ]
    logs.describe_subscription_filters.side_effect = lambda logGroupName: {
        'subscriptionFilters': (
            [{'destinationArn': FIREHOSE_ARN}] if logGroupName in routed_names else []
        )
    }

    tagging = MagicMock()
    tagging.get_paginator.return_value.paginate.return_value = [
        {'ResourceTagMappingList': [
            {'ResourceARN': log_group_arn(n),
             'Tags': [{'Key': 'terraform', 'Value': 'true'}]}
            for n in tagged_names
        ]}
    ]

    ssm = MagicMock()
    ssm.get_parameter.return_value = {'Parameter': {'Value': FIREHOSE_ARN}}

    return {'logs': logs, 'resourcegroupstaggingapi': tagging,
            'ssm': ssm, 's3': MagicMock(), 'sns': MagicMock()}


def patch_clients(clients):
    return patch.object(lambda_function, 'get_client', side_effect=clients.__getitem__)


# ── App / env resolution ──────────────────────────────────────────────────────

@pytest.mark.parametrize('name,expected_app,fallback', [
    ('bcda-dev-api', 'bcda', False),
    ('/aws/lambda/dpc_test_worker', 'dpc', False),
    ('/aws/ecs/ab2d/prod/api', 'ab2d', False),
    ('cdap-test-tftesting-service', 'cdap', False),
    ('bcda', 'bcda', False),                      # exact match, string boundaries
    ('abcda-dev-api', 'cdap', True),              # "bcda" not delimiter-bounded
    ('/aws/lambda/some-vendor-thing', 'cdap', True),
])
def test_resolve_app(name, expected_app, fallback):
    assert lambda_function.resolve_app(name) == (expected_app, fallback)


def test_resolve_app_prefers_earliest_token():
    assert lambda_function.resolve_app('cdap-test-bcda-sync') == ('cdap', False)


@pytest.mark.parametrize('name,expected_env,fallback', [
    ('bcda-dev-api', 'dev', False),
    ('ephemeral-dev-feature-x', 'dev', False),    # ephemeral prefix still resolves
    ('dpc-sandbox/api', 'sandbox', False),
    ('ab2d_prod_worker', 'prod', False),
    ('cdap-tftesting-service', 'test', True),     # "test" inside tftesting not bounded
    ('/aws/lambda/unlabeled', 'test', True),      # falls back to account env
    ('/aws/codebuild/bcda-app-non-prod', 'test', False),  # non-prod is not prod
    ('non-prod-tooling', 'test', False),          # non-prod at string start
])
def test_resolve_env(name, expected_env, fallback):
    assert lambda_function.resolve_env(name, 'test') == (expected_env, fallback)


# ── Classification ────────────────────────────────────────────────────────────

@pytest.mark.parametrize('tags,routed,exceptions,expected', [
    ({}, False, set(), 'unmanaged'),
    ({'terraform': 'true'}, False, set(), 'misconfigured'),
    ({'terraform': 'true'}, True, set(), 'compliant'),
    ({}, False, {'group-a'}, 'exception'),                      # exception wins over untagged
    ({'terraform': 'true'}, True, {'group-a'}, 'exception'),    # exception wins over compliant
    ({'terraform': 'false'}, True, set(), 'unmanaged'),         # tag must be exactly "true"
])
def test_classify(tags, routed, exceptions, expected):
    assert lambda_function.classify('group-a', tags, routed, exceptions) == expected


# ── Audit end-to-end ──────────────────────────────────────────────────────────

LOG_GROUPS = [
    '/aws/lambda/cdap-test-log-group-audit',          # compliant (cdap, test)
    'bcda-dev-api',                                   # unmanaged (bcda, dev)
    'bcda-dev-worker',                                # misconfigured (bcda, dev)
    '/aws/lambda/mystery-thing',                      # unmanaged, both fallbacks
    '/aws/kinesisfirehose/shared-test-log-retention', # exception
    'cms-cloud-vpc-flowlogs',                         # prefix-excepted: omitted
    '/aws/ec2/var/log/messages',                      # prefix-excepted: omitted
]
AUDITED_GROUPS = LOG_GROUPS[:5]  # groups expected in results after prefix skip
TAGGED = {
    '/aws/lambda/cdap-test-log-group-audit',
    'bcda-dev-worker',
    '/aws/kinesisfirehose/shared-test-log-retention',
}
ROUTED = {'/aws/lambda/cdap-test-log-group-audit'}


def run_handler(clients):
    with patch_clients(clients):
        return lambda_function.lambda_handler({}, None)


def test_audit_classifications():
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    with patch_clients(clients):
        records = {r['log_group']: r for r in lambda_function.audit()}

    assert records['/aws/lambda/cdap-test-log-group-audit']['classification'] == 'compliant'
    assert records['bcda-dev-api']['classification'] == 'unmanaged'
    assert records['bcda-dev-worker']['classification'] == 'misconfigured'
    assert records['/aws/lambda/mystery-thing']['classification'] == 'unmanaged'
    exception_record = records['/aws/kinesisfirehose/shared-test-log-retention']
    assert exception_record['classification'] == 'exception'

    # Prefix-excepted groups are omitted from results entirely
    assert 'cms-cloud-vpc-flowlogs' not in records
    assert '/aws/ec2/var/log/messages' not in records
    assert len(records) == len(AUDITED_GROUPS)

    mystery = records['/aws/lambda/mystery-thing']
    assert (mystery['app'], mystery['app_fallback']) == ('cdap', True)
    assert (mystery['env'], mystery['env_fallback']) == ('test', True)


def test_audit_skips_subscription_lookup_for_exceptions():
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    with patch_clients(clients):
        lambda_function.audit()
    called_with = {c.kwargs['logGroupName'] for c in
                   clients['logs'].describe_subscription_filters.call_args_list}
    assert '/aws/kinesisfirehose/shared-test-log-retention' not in called_with
    # Prefix-excepted groups are skipped before any per-group lookups
    assert 'cms-cloud-vpc-flowlogs' not in called_with
    assert '/aws/ec2/var/log/messages' not in called_with


def test_audit_without_exception_prefixes_audits_everything(monkeypatch):
    monkeypatch.setenv('EXCEPTION_PREFIXES', '[]')
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    with patch_clients(clients):
        records = {r['log_group'] for r in lambda_function.audit()}
    assert records == set(LOG_GROUPS)


def test_liveness_check_fails_on_malformed_exception_prefixes(monkeypatch):
    monkeypatch.setenv('EXCEPTION_PREFIXES', 'not json')
    clients = make_clients([], set(), set())
    with patch_clients(clients):
        with pytest.raises(json.JSONDecodeError):
            lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)


def test_handler_writes_results_per_owner_and_summary():
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    result = run_handler(clients)

    assert result['statusCode'] == 200
    assert result['log_groups'] == len(AUDITED_GROUPS)
    assert result['counts'] == {'compliant': 1, 'unmanaged': 2,
                                'misconfigured': 1, 'exception': 1}

    puts = {c.kwargs['Key']: json.loads(c.kwargs['Body'])
            for c in clients['s3'].put_object.call_args_list}
    assert all(c.kwargs['Bucket'] == 'cdap-test-log-group-audit'
               for c in clients['s3'].put_object.call_args_list)

    bcda_key = next(k for k in puts if k.startswith('results/app=bcda/env=dev/date='))
    assert bcda_key.endswith('/log-groups.json')
    bcda_body = puts[bcda_key]
    assert bcda_body['counts'] == {'unmanaged': 1, 'misconfigured': 1}
    assert [r['log_group'] for r in bcda_body['log_groups']] == [
        'bcda-dev-api', 'bcda-dev-worker']

    # Compliant owners are still written to S3: full results, not just findings
    assert any(k.startswith('results/app=cdap/env=test/date=') for k in puts)

    summary_key = next(k for k in puts if k.startswith('results/summary/date='))
    assert 'bcda-dev' in puts[summary_key]['owners']


def test_handler_publishes_one_alert_per_owner_with_findings():
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    result = run_handler(clients)

    publishes = clients['sns'].publish.call_args_list
    assert result['alerts_published'] == len(publishes) == 2
    messages = {json.loads(c.kwargs['Message'])['AlarmName']:
                json.loads(c.kwargs['Message']) for c in publishes}

    # One per (app, env) with findings. The cdap-test alert exists only
    # because of the unresolved mystery group, not the compliant audit lambda group
    assert set(messages) == {'bcda-dev-log-group-audit', 'cdap-test-log-group-audit'}

    bcda = messages['bcda-dev-log-group-audit']
    assert bcda['NewStateValue'] == 'ALARM'
    assert bcda['OldStateValue'] == 'OK'
    assert 'bcda-dev-api' in bcda['NewStateReason']
    assert 's3://cdap-test-log-group-audit/results/app=bcda/env=dev/' in bcda['NewStateReason']
    assert all(c.kwargs['TopicArn'] == TOPIC_ARN for c in publishes)


def test_handler_suppresses_all_alerts_with_empty_allowlist(monkeypatch):
    monkeypatch.setenv('NOTIFICATION_APPS', '[]')
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    result = run_handler(clients)

    clients['sns'].publish.assert_not_called()
    assert result['alerts_published'] == 0
    # Full results still written: two owner objects + summary
    assert clients['s3'].put_object.call_count == 3


def test_handler_alerts_only_allowlisted_apps(monkeypatch):
    monkeypatch.setenv('NOTIFICATION_APPS', '["cdap"]')
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    result = run_handler(clients)

    publishes = clients['sns'].publish.call_args_list
    names = {json.loads(c.kwargs['Message'])['AlarmName'] for c in publishes}
    # bcda-dev has findings too, but only cdap is allowlisted
    assert names == {'cdap-test-log-group-audit'}
    assert result['alerts_published'] == 1


def test_liveness_check_fails_on_malformed_notification_apps(monkeypatch):
    monkeypatch.setenv('NOTIFICATION_APPS', 'not json')
    clients = make_clients([], set(), set())
    with patch_clients(clients):
        with pytest.raises(json.JSONDecodeError):
            lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)


def test_handler_publishes_nothing_when_compliant():
    clients = make_clients(
        ['/aws/lambda/cdap-test-log-group-audit'],
        {'/aws/lambda/cdap-test-log-group-audit'},
        {'/aws/lambda/cdap-test-log-group-audit'},
    )
    result = run_handler(clients)
    assert result['alerts_published'] == 0
    clients['sns'].publish.assert_not_called()
    # Full results still written: one owner object + summary
    assert clients['s3'].put_object.call_count == 2


def test_alarm_name_parses_for_alarm_to_slack():
    """alarm-to-slack splits AlarmName on '-': parts[0]=app, parts[1]=env."""
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    run_handler(clients)
    for call in clients['sns'].publish.call_args_list:
        parts = json.loads(call.kwargs['Message'])['AlarmName'].split('-')
        assert parts[0] in lambda_function.APPS
        assert parts[1] in ['dev', 'test', 'sandbox', 'prod']


def test_new_state_reason_truncates_long_lists():
    findings = [{'log_group': f'bcda-dev-{i:02d}', 'classification': 'unmanaged'}
                for i in range(15)]
    reason = lambda_function.new_state_reason(
        'bcda', 'dev', findings, findings, 's3://bucket/key')
    assert '… and 5 more' in reason
    assert '15 of 15' in reason


# ── Account ID scrubbing ──────────────────────────────────────────────────────

def test_log_masks_account_ids(capsys):
    lambda_function.log({'msg': 'arn:aws:sns:us-east-1:123456789012:cdap-alarms'})
    out = capsys.readouterr().out
    assert '123456789012' not in out
    assert '[REDACTED]' in out


def test_alerts_mask_account_ids():
    name = '/aws/codebuild/123456789012-bcda-dev-build'
    clients = make_clients([name], set(), set())
    run_handler(clients)
    message = clients['sns'].publish.call_args.kwargs['Message']
    assert '123456789012' not in message
    assert '[REDACTED]' in message


def test_liveness_failure_masks_account_ids():
    clients = make_clients([], set(), set())
    clients['ssm'].get_parameter.side_effect = lambda_function.ClientError(
        {'Error': {'Code': 'AccessDenied',
                   'Message': 'User arn:aws:sts::123456789012:assumed-role/x denied'}},
        'GetParameter')
    with patch_clients(clients):
        with pytest.raises(RuntimeError, match='Firehose ARN') as excinfo:
            lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)
    assert '123456789012' not in str(excinfo.value)
    assert excinfo.value.__cause__ is None  # no chained raw boto error in logs


def test_audit_failure_masks_account_ids():
    clients = make_clients(LOG_GROUPS, TAGGED, ROUTED)
    clients['s3'].put_object.side_effect = lambda_function.ClientError(
        {'Error': {'Code': 'AccessDenied',
                   'Message': 'arn:aws:s3:::123456789012-bucket denied'}},
        'PutObject')
    with pytest.raises(RuntimeError, match='Audit failed') as excinfo:
        run_handler(clients)
    assert '123456789012' not in str(excinfo.value)
    assert excinfo.value.__cause__ is None


# ── Liveness check ────────────────────────────────────────────────────────────

def test_liveness_check_passes():
    clients = make_clients([], set(), set())
    with patch_clients(clients):
        result = lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)
    assert result['statusCode'] == 200


def test_liveness_check_fails_on_missing_env():
    with patch.dict(os.environ, {'RESULTS_BUCKET': ''}):
        with pytest.raises(RuntimeError, match='RESULTS_BUCKET'):
            lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)


def test_liveness_check_fails_on_unreadable_parameter():
    clients = make_clients([], set(), set())
    clients['ssm'].get_parameter.side_effect = (
        lambda_function.ClientError({'Error': {'Code': 'ParameterNotFound'}},
                                    'GetParameter'))
    with patch_clients(clients):
        with pytest.raises(RuntimeError, match='Firehose ARN'):
            lambda_function.lambda_handler({'RequestType': 'LivenessCheck'}, None)
