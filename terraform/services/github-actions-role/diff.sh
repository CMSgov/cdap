#!/bin/zsh
# policy_diff.sh
# usage: ./policy_diff.sh <app> <env>
# example: ./policy_diff.sh cdap prod
#
# Relies on the same tfi/tfa conventions:
#   - backend config at ../../backends/${app}-${env}.s3.tfbackend
#   - TF_VAR_env and TF_VAR_app passed as env vars

APP="${1:-${TF_VAR_app:-cdap}}"
ENV="${2:-${TF_VAR_env:-test}}"
ROLE_NAME="${APP}-${ENV}-github-actions"
BACKEND_FILE="${APP}-${ENV}.s3.tfbackend"
TMPDIR=$(mktemp -d)

echo "=== Diffing IAM policy for role: ${ROLE_NAME} ==="

# ── INIT (mirrors tfi behavior) ──────────────────────────────────────────────
_tofu_clean() {
  echo "Cleaning local state files..."
  rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
  rm -rf .terraform
}

_tofu_backend_matches() {
  local target_backend="$1"
  local backend_state=".terraform/terraform.tfstate"
  if [[ ! -f "$backend_state" ]]; then
    return 1
  fi
  if grep -q "${target_backend}" "$backend_state" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

if _tofu_backend_matches "${BACKEND_FILE}"; then
  echo "Backend already configured for ${BACKEND_FILE}, skipping clean."
else
  echo "Backend change detected (target: ${BACKEND_FILE}), cleaning state..."
  _tofu_clean
fi

TF_VAR_env="${ENV}" TF_VAR_app="${APP}" \
  tofu init \
  -backend-config="../../backends/${BACKEND_FILE}" > /dev/null

# ── BEFORE ──────────────────────────────────────────────────────────────────
echo "Fetching current inline policy from AWS..."

# Dynamically get the inline policy name rather than hardcoding it
INLINE_POLICY_NAME=$(aws iam list-role-policies \
  --role-name "${ROLE_NAME}" \
  --query "PolicyNames[0]" \
  --output text 2>/dev/null)

if [[ -z "${INLINE_POLICY_NAME}" || "${INLINE_POLICY_NAME}" == "None" ]]; then
  echo "ℹ️  No inline policy found for ${ROLE_NAME} — will show new policy as net-new."
  echo "[]" > "${TMPDIR}/before_actions.json"
else
  echo "Found inline policy: ${INLINE_POLICY_NAME}"
  aws iam get-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-name "${INLINE_POLICY_NAME}" \
    --query "PolicyDocument" \
    --output json \
    | jq '[
        .Statement[].Action |
        if type == "array" then .[] else . end
      ] | flatten | sort | unique' \
    > "${TMPDIR}/before_actions.json"
fi

if [[ ! -s "${TMPDIR}/before_actions.json" ]]; then
  echo "⚠️  Could not fetch current inline policy — does it exist for ${ROLE_NAME}?"
  rm -rf "${TMPDIR}"
  exit 1
fi

if jq -e '. == ["*"]' "${TMPDIR}/before_actions.json" > /dev/null 2>&1; then
  echo "⚠️  WARNING: Current policy is a wildcard (*) — this role has admin-level access!"
  echo "   The diff below shows the new explicit permissions replacing the wildcard."
  echo ""
fi

# ── AFTER ────────────────────────────────────────────────────────────────────
echo "Running tofu plan..."
TF_VAR_env="${ENV}" TF_VAR_app="${APP}" \
  tofu plan \
  -var="app=${APP}" \
  -var="env=${ENV}" \
  -out="${TMPDIR}/tfplan" > /dev/null

tofu show -json "${TMPDIR}/tfplan" \
  | jq '[
      .resource_changes[] |
      select(.type == "aws_iam_policy") |
      .change.after.policy |
      fromjson |
      .Statement[].Action |
      if type == "array" then .[] else . end
    ] | flatten | sort | unique' \
  > "${TMPDIR}/after_actions.json"

# ── DIFF ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== REMOVED actions (in old, not in new) ==="
comm -23 \
  <(jq -r '.[]' "${TMPDIR}/before_actions.json" | sort) \
  <(jq -r '.[]' "${TMPDIR}/after_actions.json" | sort) \
  | sed 's/^/  /'

echo ""
echo "=== ADDED actions (in new, not in old) ==="
comm -13 \
  <(jq -r '.[]' "${TMPDIR}/before_actions.json" | sort) \
  <(jq -r '.[]' "${TMPDIR}/after_actions.json" | sort) \
  | sed 's/^/  /'

echo ""
echo "=== UNCHANGED action count ==="
comm -12 \
  <(jq -r '.[]' "${TMPDIR}/before_actions.json" | sort) \
  <(jq -r '.[]' "${TMPDIR}/after_actions.json" | sort) \
  | wc -l | tr -d ' '

# ── CLEANUP ──────────────────────────────────────────────────────────────────
rm -rf "${TMPDIR}"
