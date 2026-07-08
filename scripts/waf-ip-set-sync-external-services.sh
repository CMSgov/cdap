#!/bin/bash

# TODO remove this logic in favor of SOPS stored IP lists retrieved and set via Tofu
set -euo pipefail

IPV4_LIST=$(grep -v '^#' temp/ip-sets/external-services/allowed_ips.txt | jq -Rs '{Addresses: split("\n") | map(select(length > 0))}' | jq -rc .Addresses)
IPV4_SET_ID=$(aws wafv2 list-ip-sets --scope REGIONAL --region $AWS_REGION | jq -r '.IPSets[] | select( .Name=="external-services") | .Id')

LOCK_TOKEN=$(aws wafv2 get-ip-set --name external-services --scope REGIONAL --id $IPV4_SET_ID --region us-east-1 | jq -r '.LockToken')

echo "Beginning 'external services' IPv4 set update."

aws wafv2 update-ip-set \
  --name external-services \
  --scope REGIONAL \
  --id $IPV4_SET_ID \
  --region us-east-1 \
  --addresses $IPV4_LIST \
  --lock-token $LOCK_TOKEN
