#!/bin/bash

set -euo pipefail


usage() {
  echo "Usage: $0 [--dry-run]"
  exit 1
}

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
elif [[ -n "${1:-}" ]]; then
  usage
fi

echo "Select target:"
select PREFIX in ab2d bcda dpc; do
  if [[ -n "$PREFIX" ]]; then
    break
  else
    echo "Invalid selection. Choose 1, 2, or 3."
  fi
done

echo "Fetching secrets with prefix '$PREFIX'..."

SECRETS=$(aws secretsmanager list-secrets \
  --query "SecretList[?contains(Name, \`${PREFIX}\`)].ARN" \
  --output text)

if [[ -z "$SECRETS" ]]; then
  echo "No secrets found matching '$PREFIX'."
  exit 0
fi

for SECRET_ARN in $SECRETS; do
  if $DRY_RUN; then
    echo "[Dry Run] Would delete: $SECRET_ARN"
  else
    echo "Deleting: $SECRET_ARN"
    aws secretsmanager delete-secret --secret-id "$SECRET_ARN" --force-delete-without-recovery
  fi
done

echo "Done."

