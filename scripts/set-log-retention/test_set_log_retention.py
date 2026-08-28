# scripts/set-log-retention/test_set_log_retention.py
"""Starter tests for set-log-retention — expand as plan-building logic grows."""

import json
from unittest.mock import MagicMock

import set-log-retention as slr


def test_build_plan_flags_log_groups_missing_retention():
    """A log group with no retention set should appear in the generated plan."""
    mock_logs = MagicMock()
    mock_logs.get_paginator.return_value.paginate.return_value = [
        {'logGroups': [{'logGroupName': '/aws/lambda/example', 'retentionInDays': None}]}
    ]
    plan = slr.build_plan(mock_logs, retention_days=180)
    assert any(cmd['logGroupName'] == '/aws/lambda/example' for cmd in plan['commands'])
