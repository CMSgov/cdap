#!/usr/bin/env python3
"""
AWS CloudWatch Log Group Retention Policy Manager

Modes:
  plan  - Scans log groups matching TARGET_ENV, generates a JSON plan + CSV report.
  apply - Reads an approved plan file and applies retention policies.

Environment variables:
  MODE           = plan | apply        (default: plan)
  PLAN_FILE      = path to plan JSON   (required in apply mode)
  AWS_REGION     = AWS region          (default: us-east-1)
  RETENTION_DAYS = days                (default: 180)
  TARGET_ENV     = environment string  (default: prod)
                   Only log groups whose names CONTAIN this string are processed.
                   Env options: "prod", "test", "dev", "sandbox", these will include ephemeral environments
"""

import boto3
import csv
import json
import os
import sys
from datetime import datetime

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
AWS_REGION     = os.environ.get("AWS_REGION", "us-east-1")
RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "180"))
TARGET_ENV     = os.environ.get("TARGET_ENV", "prod").lower()

DATE_TAG    = datetime.now().strftime("%Y%m%d-%H%M%S")
PLAN_FILE   = f"retention-plan-{DATE_TAG}.json"
REPORT_FILE = f"retention-report-{DATE_TAG}.csv"

# Log groups excluded because their retention is managed by Terraform.
EXCLUSION_LIST = {
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_job_data",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-bfd-insights-get_stale_pending_jobs",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_active_acos",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_stale_cclf_imports",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_num_benes_per_aco",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_suppression_metrics",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_num_days_to_make_first_request",
    "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_acos_with_expired_credentials",
    "aws/kinesisfirehose/bfd-insights-bcda-prod-get_job_data",  # intentional: no leading slash
    "/aws/lambda/insights_data_sampler_prod",
    "/aws/lambda/ab2d-prod-audit",
    "/aws/lambda/ab2d-sandbox-audit",
    "/aws/lambda/ab2d-test-audit",
    "/aws/lambda/ab2d-dev-audit",
    "/aws/events/ecs/dpc-prod-backend",
    "/aws/events/ecs/dpc-prod-frontend",
}
# ---------------------------------------------------------------------------

# Helpers

def get_all_log_groups(client: boto3.client) -> list[dict]:
    """Return every CloudWatch log group using the boto3 paginator."""
    log_groups = []
    paginator = client.get_paginator("describe_log_groups")
    for page in paginator.paginate():
        log_groups.extend(page.get("logGroups", []))
    return log_groups


def evaluate_log_group(name: str, retention) -> tuple[str, str, int]:
    """
    Categorise a single log group.

    Returns
    -------
    (category, lower_name, effective_retention)

    Categories
    ----------
    tf_maintained  – in the explicit exclusion list
    ignored_env    – name does NOT contain TARGET_ENV (wrong environment)
    ignored_cms    – name contains cms-cloud
    skipped        – retention already meets or exceeds the target
    update         – needs a retention policy update
    """
    lower_name = name.lower()

    # 1. Explicit Terraform-managed exclusion list to prevent conflicts
    if lower_name in EXCLUSION_LIST:
        return ("tf_maintained", lower_name, retention or 0)

    # 2. Skip log groups that don't belong to the target environment
    if TARGET_ENV not in lower_name:
        return ("ignored_env", lower_name, retention or 0)

    # 3. CMS-managed log groups
    if "cms-cloud" in lower_name:
        return ("ignored_cms", lower_name, retention or 0)

    # 4. Retention already sufficient
    effective_retention = retention if retention is not None else 0
    if effective_retention >= RETENTION_DAYS:
        return ("skipped", lower_name, effective_retention)

    # 5. Needs update
    return ("update", lower_name, effective_retention)


def build_cli_command(log_group_name: str) -> str:
    """Return the equivalent AWS CLI command string (for human review only)."""
    return (
        f"aws logs put-retention-policy"
        f" --log-group-name \"{log_group_name}\""
        f" --retention-in-days {RETENTION_DAYS}"
        f" --region {AWS_REGION}"
    )


# Plan

def generate_plan(log_groups: list[dict]) -> tuple[dict, list[dict]]:
    """
    Walk every log group, categorise it, and build the list of commands
    that need to be applied.

    Returns (results_dict, commands_list).
    """
    results = {
        "processed":     0,
        "to_update":     [],
        "skipped":       [],
        "tf_maintained": [],
        "ignored_cms":   [],
        "ignored_env":   [],
    }
    commands = []

    for group in log_groups:
        name      = group.get("logGroupName", "")
        retention = group.get("retentionInDays")   # None when not set
        results["processed"] += 1

        category, lower_name, effective_retention = evaluate_log_group(name, retention)
        print(f"  [{category.upper():>13}]  {lower_name}")

        if category == "tf_maintained":
            results["tf_maintained"].append({"name": name, "retention": retention})

        elif category == "ignored_env":
            results["ignored_env"].append({"name": name, "retention": retention})

        elif category == "ignored_cms":
            results["ignored_cms"].append({"name": name})

        elif category == "skipped":
            results["skipped"].append({"name": name, "retention": effective_retention})

        elif category == "update":
            commands.append({
                "log_group":         lower_name,
                "current_retention": effective_retention,
                "cli_command":       build_cli_command(lower_name),
            })
            results["to_update"].append({
                "name":              lower_name,
                "current_retention": effective_retention,
            })

    return results, commands

def write_plan_file(commands: list[dict]) -> str:
    """Serialise the command list to a timestamped JSON file. Returns the filename."""
    payload = {
        "generated_at":   DATE_TAG,
        "region":         AWS_REGION,
        "retention_days": RETENTION_DAYS,
        "target_env":     TARGET_ENV,
        "commands":       commands,
    }
    with open(PLAN_FILE, "w") as fh:
        json.dump(payload, fh, indent=2)
    print(f"\nPlan written  → {PLAN_FILE}")
    return PLAN_FILE
