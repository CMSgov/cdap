#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:us-east-1}"
RETENTION_DAYS="${RETENTION_DAYS:-180}"
DRY_RUN="${DRY_RUN:-true}"

DATE_TAG=$(date +%Y%m%d-%H%M%S)
PLAN_FILE="retention-plan-${DATE_TAG}.sh"
REPORT_FILE="retention-report-${DATE_TAG}.csv"

PROCESSED=0
IGNORED_CMS=0
UPDATED=()
SKIPPED=()
IGNORED=()

echo "REGION: $AWS_REGION"
echo "Target retention: "
echo "Dry run: $DRY_RUN"
echo "Plan file: $PLAN_FILE"
echo "Report file: $REPORT_FILE"
echo "--------------------------------------"

aws logs describe-log-groups \
    --region "$AWS_REGION"
    --query 'logGroups[*].[logGroupName, retentionInDays]' \
    --output text |
while read -r NAME RETENTION; do
    ((PROCESSED++))
    LOWER_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
    echo "Working on $LOWER_NAME"

    if [[ "$LOWER_NAME" == *dev* ]] \
      [[ "$LOWER_NAME" == *test* ]]
      [[ "$LOWER_NAME" == *sandbox* ]]; then
        IGNORED+=("$NAME")
        echo "ignored ${LOWER_NAME}"
        continue
    fi

    if echo "$LOWER_NAME" | grep -iq "cms-cloud"; then
        ((IGNORED_CMS++))
        echo "ignored ${LOWER_NAME}"
        continue
    fi

    if [[ "$RETENTION" == "None" ]]; then
        RETENTION=0
    fi

    if [[ "$RETENTION" -ge "$RETENTION_DAYS" ]]; then
        SKIPPED+=("$NAME")
        echo "skipped ${LOWER_NAME}"
        continue
    fi

    echo "Updating: $NAME (current: ${RETENTION:-unset})"
    CMD=(
      aws logs put-retention-policy \
        --region "$AWS_REGION" \
        --log-group-name "$NAME" \
        --retention-in-days "$RETENTION_DAYS"
    )

    if [[ "DRY_RUN" == "true" ]]; then
      printf '%q ' "${CMD[@]}" >> "$PLAN_FILE"
      echo >> "$PLAN_FILE"
    else
      read -p "Run retention update for: $NAME (current: ${RETENTION:-unset})? [y/N] " CONFIRM
      if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        if "${CMD[@]}"; then
          echo "Updated $NAME"
        else
          echo "Error updating $NAME"
        fi
      else
        echo "SKIPPED $NAME"
    fi

    UPDATED+=("$NAME")
done

echo "----------------------"
echo "Updated: $UPDATED"
for name in "${UPDATED}"; do echo "updated,$name\n"; done

echo "Updated: $IGNORED"
for name in "${IGNORED}"; do echo "updated,$name\n"; done

echo "Updated: $SKIPPED"
for name in "${SKIPPED}"; do echo "updated,$name"; done

echo "Ignored (cms-cloud managed): $IGNORED_CMS"