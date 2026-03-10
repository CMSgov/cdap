#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="${AWS_REGION:=us-east-1}"
RETENTION_DAYS="${RETENTION_DAYS:-180}"
DRY_RUN="${DRY_RUN:-true}"

DATE_TAG=$(date +%Y%m%d-%H%M%S)
PLAN_FILE="retention-plan-${DATE_TAG}.sh"
REPORT_FILE="retention-report-${DATE_TAG}.csv"

PROCESSED=0
IGNORED_CMS=()
UPDATED=()
SKIPPED=()
IGNORED=()
TF_MAINTAINED=()

# These log groups are excluded because their values are set via Terraform.
# Defined explicitly because some Terraform managed log groups do not have retention set via Terraform
EXCLUSION_LIST=(
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_job_data"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-bfd-insights-get_stale_pending_jobs"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_active_acos"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_stale_cclf_imports"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_num_benes_per_aco"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_suppression_metrics"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_num_days_to_make_first_request"
  "/aws/kinesisfirehose/bfd-insights-bcda-prod-get_acos_with_expired_credentials"
  "aws/kinesisfirehose/bfd-insights-bcda-prod-get_job_data"
  "/aws/lambda/insights_data_sampler_prod"
  "/aws/lambda/ab2d-prod-audit"
  "/aws/lambda/ab2d-sandbox-audit"
  "/aws/lambda/ab2d-test-audit"
  "/aws/lambda/ab2d-dev-audit"
  "/aws/events/ecs/dpc-prod-backend"
  "/aws/events/ecs/dpc-prod-frontend"
)

if [[ "$DRY_RUN" == "true" ]]; then
  echo "#!/usr/bin/env bash" > "$PLAN_FILE"
  echo "set -euo pipefail" >> $PLAN_FILE
  echo "" >> "$PLAN_FILE"
fi

echo "REGION: $AWS_REGION"
echo "Target retention: "
echo "Dry run: $DRY_RUN"
echo "Plan file: $PLAN_FILE"
echo "Report file: $REPORT_FILE"
echo "--------------------------------------"

LOG_GROUPS_JSON=$(aws logs describe-log-groups --region "$AWS_REGION" --output json)
while IFS=$'\t' read -r NAME RETENTION; do

    ((PROCESSED++))

    LOWER_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
    echo "Evaluating: $LOWER_NAME"

    EXCLUDE=false

    for excluded_group_name in "${EXCLUSION_LIST[@]}"; do
      if [[ "$excluded_group_name" == "$LOWER_NAME" ]]; then
        EXCLUDE=true
        break # Exit the loop once a match is found
      fi
    done

    if [[ "$EXCLUDE" == true ]] ; then
        TF_MAINTAINED+=("$NAME $RETENTION")
        continue
    fi

    if [[ "$LOWER_NAME" == *dev* ]] || \
      [[ "$LOWER_NAME" == *test* ]] || \
      [[ "$LOWER_NAME" == *sandbox* ]]; then
        IGNORED+=("$NAME $RETENTION")
        echo "IGNORING (uncovered environment) ${LOWER_NAME}"
        continue
    fi

    if echo "$LOWER_NAME" | grep -iq "cms-cloud"; then
        IGNORED_CMS+=("$NAME")
        echo "IGNORING (cms managed) ${LOWER_NAME}"
        continue
    fi

    if [[ "$RETENTION" == "null" ]]; then
        RETENTION=0
    fi

    if [[ "$RETENTION" -ge "$RETENTION_DAYS" ]]; then
        SKIPPED+=("$NAME $RETENTION")
        echo "SKIPPING (retention sufficient) ${LOWER_NAME} "
        continue
    fi

    CMD=(
      aws logs put-retention-policy \
      --log-group-name "$LOWER_NAME" \
      --retention-in-days "$RETENTION"
    )

    if [[ "$DRY_RUN" == "true" ]]; then
      printf '%q ' "${CMD[@]}" >> "$PLAN_FILE"
      echo >> "$PLAN_FILE"
    else
      read -p "Run retention update for: $LOWER_NAME (current: ${RETENTION:-unset})? [y/N] " CONFIRM
      if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        if "${CMD[@]}"; then
          echo "UPDATED $LOWER_NAME"
          UPDATED+=("$LOWER_NAME")
        else
          echo "Error updating $LOWER_NAME"
        fi
      else
        echo "SKIPPING: $LOWER_NAME"
        SKIPPED+=("$LOWER_NAME")
      fi
    fi


done < <(jq -r '.logGroups[] | "\(.logGroupName)\t\(.retentionInDays // "null")"' <<< "$LOG_GROUPS_JSON")

# Summary #

echo "----------------------"
echo "ALL UPDATED: (${#UPDATED[@]})"
printf " %s\n" "${UPDATED[@]:-}"

echo "----------------------"
echo "MAINTAINED BY TF AND SKIPPED: (${#TF_MAINTAINED[@]})"
printf " %s\n" "${TF_MAINTAINED[@]:-}"

echo "----------------------"
echo "ALL OTHERS SKIPPED: (${#SKIPPED[@]})"
printf " %s\n" "${SKIPPED[@]:-}"

echo "----------------------"
echo "CMS MANAGED AND IGNORED: (${#IGNORED_CMS[@]})"
printf " %s\n" "${IGNORED_CMS[@]:-}"

echo "----------------------"
echo "ALL IGNORED: (${#IGNORED[@]})"
printf " %s\n" "${IGNORED[@]:-}"

echo "total processed: $PROCESSED"
