"""
Unit tests for the CloudWatch log retention manager script.
"""

import json
import sys
from unittest.mock import MagicMock

import pytest

import set_log_retention as slr
from botocore.exceptions import ClientError

def test_evaluate_log_group_tf_maintained(monkeypatch):
    """A log group in the exclusion list is categorized tf_maintained, regardless of env or retention."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {'/aws/lambda/managed-elsewhere'})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    category, name, retention = slr.evaluate_log_group('/aws/lambda/managed-elsewhere', 30)
    assert category == 'tf_maintained'
    assert name == '/aws/lambda/managed-elsewhere'
    assert retention == 30


def test_evaluate_log_group_ignored_env(monkeypatch):
    """A log group whose name doesn't contain TARGET_ENV is ignored_env."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    category, _, _ = slr.evaluate_log_group('/aws/lambda/dpc-test-worker', None)
    assert category == 'ignored_env'


def test_evaluate_log_group_ignored_cms(monkeypatch):
    """A log group matching the target env but containing cms-cloud is ignored_cms."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    category, _, _ = slr.evaluate_log_group('/aws/lambda/cms-cloud-prod-agent', None)
    assert category == 'ignored_cms'


def test_evaluate_log_group_skipped_when_retention_sufficient(monkeypatch):
    """A log group already at or above RETENTION_DAYS is skipped."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)
    category, _, effective = slr.evaluate_log_group('/aws/lambda/dpc-prod-worker', 365)
    assert category == 'skipped'
    assert effective == 365


def test_evaluate_log_group_update_when_retention_missing(monkeypatch):
    """A matching log group with no retention set (None) needs an update."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)
    category, _, effective = slr.evaluate_log_group('/aws/lambda/dpc-prod-worker', None)
    assert category == 'update'
    assert effective == 0


def test_evaluate_log_group_update_when_retention_too_low(monkeypatch):
    """A matching log group with retention below RETENTION_DAYS needs an update."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)
    category, _, effective = slr.evaluate_log_group('/aws/lambda/dpc-prod-worker', 30)
    assert category == 'update'
    assert effective == 30


def test_evaluate_log_group_priority_exclusion_beats_cms(monkeypatch):
    """Exclusion-list membership wins even if the name would also match ignored_cms."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {'/aws/lambda/cms-cloud-prod-agent'})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    category, _, _ = slr.evaluate_log_group('/aws/lambda/cms-cloud-prod-agent', None)
    assert category == 'tf_maintained'


def test_build_cli_command_format(monkeypatch):
    """The generated CLI command includes the log group, retention, and region."""
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)
    monkeypatch.setattr(slr, 'AWS_REGION', 'us-east-1')
    cmd = slr.build_cli_command('/aws/lambda/dpc-prod-worker')
    assert '--log-group-name "/aws/lambda/dpc-prod-worker"' in cmd
    assert '--retention-in-days 180' in cmd
    assert '--region us-east-1' in cmd


def test_get_all_log_groups_paginates():
    """All log groups across multiple pages are collected into one list."""
    mock_client = MagicMock()
    mock_paginator = MagicMock()
    mock_paginator.paginate.return_value = [
        {'logGroups': [{'logGroupName': '/aws/lambda/a'}]},
        {'logGroups': [{'logGroupName': '/aws/lambda/b'}]},
    ]
    mock_client.get_paginator.return_value = mock_paginator
    result = slr.get_all_log_groups(mock_client)
    assert [g['logGroupName'] for g in result] == ['/aws/lambda/a', '/aws/lambda/b']


def test_get_all_log_groups_handles_missing_key():
    """A page with no logGroups key contributes nothing, rather than raising."""
    mock_client = MagicMock()
    mock_paginator = MagicMock()
    mock_paginator.paginate.return_value = [{}]
    mock_client.get_paginator.return_value = mock_paginator
    assert slr.get_all_log_groups(mock_client) == []

def test_generate_plan_categorizes_and_builds_commands(monkeypatch):
    """generate_plan aggregates log groups into the right buckets and builds update commands."""
    monkeypatch.setattr(slr, 'EXCLUSION_LIST', {})
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)

    log_groups = [
        {'logGroupName': '/aws/lambda/dpc-prod-worker', 'retentionInDays': None},   # update
        {'logGroupName': '/aws/lambda/dpc-prod-api', 'retentionInDays': 365},       # skipped
        {'logGroupName': '/aws/lambda/dpc-test-worker', 'retentionInDays': None},   # ignored_env
        {'logGroupName': '/aws/lambda/cms-cloud-prod-agent', 'retentionInDays': None},  # ignored_cms
    ]

    results, commands = slr.generate_plan(log_groups)

    assert results['processed'] == 4
    assert len(commands) == 1
    assert commands[0]['log_group'] == '/aws/lambda/dpc-prod-worker'
    assert len(results['skipped']) == 1
    assert len(results['ignored_env']) == 1
    assert len(results['ignored_cms']) == 1
    assert len(results['to_update']) == 1


def test_generate_plan_empty_input():
    """An empty log group list produces an empty, valid results structure."""
    results, commands = slr.generate_plan([])
    assert results['processed'] == 0
    assert commands == []


def test_write_plan_file_writes_expected_json(tmp_path, monkeypatch):
    """The plan file is written with the expected structure and returned filename."""
    plan_path = tmp_path / 'retention-plan-test.json'
    monkeypatch.setattr(slr, 'PLAN_FILE', str(plan_path))
    monkeypatch.setattr(slr, 'RETENTION_DAYS', 180)
    monkeypatch.setattr(slr, 'TARGET_ENV', 'prod')
    monkeypatch.setattr(slr, 'AWS_REGION', 'us-east-1')

    commands = [{'log_group': '/aws/lambda/dpc-prod-worker', 'current_retention': 0,
                 'cli_command': 'aws logs put-retention-policy ...'}]
    result_path = slr.write_plan_file(commands)

    assert result_path == str(plan_path)
    written = json.loads(plan_path.read_text())
    assert written['retention_days'] == 180
    assert written['target_env'] == 'prod'
    assert written['commands'] == commands


def test_apply_plan_missing_file_exits(tmp_path):
    """apply_plan exits with code 1 if the plan file doesn't exist."""
    mock_client = MagicMock()
    missing_path = str(tmp_path / 'does-not-exist.json')
    with pytest.raises(SystemExit) as exc_info:
        slr.apply_plan(mock_client, missing_path)
    assert exc_info.value.code == 1

def test_apply_plan_success(tmp_path, monkeypatch):
    """A successful apply calls put_retention_policy for every planned log group."""
    report_path = tmp_path / 'retention-report-test.csv'
    monkeypatch.setattr(slr, 'REPORT_FILE', str(report_path))

    plan_path = tmp_path / 'retention-plan-test.json'
    plan_path.write_text(json.dumps({
        'retention_days': 180,
        'region': 'us-east-1',
        'commands': [{'log_group': '/aws/lambda/dpc-prod-worker', 'current_retention': 0}],
    }))

    mock_client = MagicMock()
    slr.apply_plan(mock_client, str(plan_path))

    mock_client.put_retention_policy.assert_called_once_with(
        logGroupName='/aws/lambda/dpc-prod-worker',
        retentionInDays=180,
    )
    assert report_path.exists()


def test_apply_plan_partial_failure_exits_1(tmp_path, monkeypatch):
    """If any put_retention_policy call fails, apply_plan reports it and exits with code 1."""
    report_path = tmp_path / 'retention-report-test.csv'
    monkeypatch.setattr(slr, 'REPORT_FILE', str(report_path))

    plan_path = tmp_path / 'retention-plan-test.json'
    plan_path.write_text(json.dumps({
        'retention_days': 180,
        'region': 'us-east-1',
        'commands': [
            {'log_group': '/aws/lambda/dpc-prod-good', 'current_retention': 0},
            {'log_group': '/aws/lambda/dpc-prod-bad', 'current_retention': 0},
        ],
    }))

    mock_client = MagicMock()
    error_response = {"Error": {"Code": "AccessDeniedException", "Message": "AccessDenied"}}
    mock_client.put_retention_policy.side_effect = [
        None,
        ClientError(error_response, "PutRetentionPolicy"),
    ]

    plan_path_str = str(plan_path)
    with pytest.raises(SystemExit) as exc_info:
        slr.apply_plan(mock_client, plan_path_str)
    assert exc_info.value.code == 1

    report_rows = report_path.read_text()
    assert 'dpc-prod-bad' in report_rows
    assert 'failed' in report_rows

def test_write_report_writes_csv(tmp_path, monkeypatch):
    """write_report produces a CSV with the expected header and rows."""
    report_path = tmp_path / 'report.csv'
    monkeypatch.setattr(slr, 'REPORT_FILE', str(report_path))

    slr.write_report([
        {'log_group': '/aws/lambda/x', 'status': 'updated', 'retention': 180, 'error': ''},
    ])

    content = report_path.read_text()
    assert 'log_group,status,retention,error' in content
    assert '/aws/lambda/x,updated,180,' in content


def test_write_report_no_rows_is_noop(tmp_path, monkeypatch):
    """write_report does nothing (no file created) when given an empty row list."""
    report_path = tmp_path / 'should-not-exist.csv'
    monkeypatch.setattr(slr, 'REPORT_FILE', str(report_path))
    slr.write_report([])
    assert not report_path.exists()


def test_main_unknown_mode_exits_1(monkeypatch):
    """An unrecognized MODE value causes main() to exit with code 1."""
    monkeypatch.setenv('MODE', 'bogus')
    with pytest.raises(SystemExit) as exc_info:
        slr.main()
    assert exc_info.value.code == 1


def test_main_apply_without_plan_file_exits_1(monkeypatch):
    """apply mode without PLAN_FILE set exits with code 1 before touching AWS."""
    monkeypatch.setenv('MODE', 'apply')
    monkeypatch.delenv('PLAN_FILE', raising=False)
    with pytest.raises(SystemExit) as exc_info:
        slr.main()
    assert exc_info.value.code == 1
