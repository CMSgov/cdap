#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:us-east-1}"
RETENTION_DAYS="${RETENTION_DAYS:-180}"
DRY_RUN="${DRY_RUN:-true}"

PROCESSED=0
IGNORED_CMS=0
UPDATED=()
SKIPPED=()
IGNORED=()

echo "REGION: $AWS_REGION"
echo "Target retention: "


aws logs describe-log-groups \
    --region "$AWS_REGION"
    --query 'logGroups[*].[logGroupName, retentionInDays]' \
    --output text |
while read -r NAME RETENTION; do
    ((PROCESSED++))
    LOWER_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')

    if [[ "$LOWER_NAME" == *dev* ]] \
      [[ "$LOWER_NAME" == *test* ]]
      [[ "$LOWER_NAME" == *sandbox* ]]; then
        IGNORED+=("$NAME")
        continue
    fi

    if echo "$LOWER_NAME" | grep -iq "cms-cloud"; then
        ((IGNORED_CMS++))
        continue
    fi

    if [[ "$RETENTION" == "None" ]]; then
        RETENTION=""
    fi

    if [[ "$RETENTION" -ge "$RETENTION_DAYS" ]]; then
        SKIPPED+=("$NAME")
        continue
    fi

    echo "Updating: $NAME (current: ${RETENTION:-unset})"

    if [[ "DRY_RUN" != "true" ]]; then
        aws logs put-retentionpolicy \
          --region "$AWS_REGION" \
          --log-group-name "$NAME" \
          --retention-in-days "$RETENTION_DAYS"

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