#!/bin/bash

# Strict. Exit if something bad happens.
set -euo pipefail

# This script assumes 'httpie' is installed.
API_KEY_ADMIN="abcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefgh"
API_KEY_LOG="1234567890123456123456789012345612345678901234561234567890123456"
HOST="localhost"
PORT="8888"
SCHEME="http"

assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Expected '$expected' but got '$actual'}"

    if [ "$expected" != "$actual" ]; then
        echo "Assertion Failed: $msg" >&2
        exit 1
    fi
}

# Check the health status
http --check-status --ignore-stdin GET \
    ${SCHEME}://${HOST}:${PORT}/v1/health \
    | assert_equals "ok" $(jq -r .status)


# Can we post an event?
http --check-status --ignore-stdin POST \
    ${SCHEME}://${HOST}:${PORT}/v1/log/create \
    x-api-key:${API_KEY_LOG} \
    tags[]="a" \
    | assert_equals "ok" $(jq -r .status)

# Can we post a few events, with some changing data?
for i in {1..10}; do
    http --check-status --ignore-stdin POST \
        ${SCHEME}://${HOST}:${PORT}/v1/log/create \
        x-api-key:${API_KEY_LOG} \
        tags[]="numbers" \
        data[number]:=${i} |
        assert_equals "ok" $(jq -r .status)
done

# how about consolidating into a summary day
http --check-status --ignore-stdin POST \
    ${SCHEME}://${HOST}:${PORT}/v1/summary/create/daily \
    x-api-key:${API_KEY_ADMIN} \
    operation="test.create.summary" \
    tags[]="one" \
    tags[]="two" \
    data[]="required" \
    YYYYMMDD="$(date +%Y-%m-%d)"
