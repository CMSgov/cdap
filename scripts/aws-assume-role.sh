# shellcheck shell=sh
# Start AWS session for MFA-enabled account

# https://stackoverflow.com/questions/61784326/zsh-bash-source-command-behavior-difference
# shellcheck disable=SC2128,SC3028
if { [ -n "$BASH_VERSION" ] && [ "$BASH_SOURCE" = "$0" ]; } ||
    { [ -n "$ZSH_VERSION" ] && [ "$ZSH_EVAL_CONTEXT" = "toplevel" ]; }; then
  echo 2>&1 "This script must be sourced, not executed. Try \"source $0\""
  exit 1
fi

# https://stackoverflow.com/questions/9901210/bash-source0-equivalent-in-zsh
# shellcheck disable=SC2296
if { [ -z "$1" ]; }; then
  echo 2>&1 "Usage: source ${BASH_SOURCE:-${(%):-%x}} <role_arn>"
  echo 2>&1 "Where <role_arn> is the ARN for the AWS role to be assumed."
  return 1
fi

tmpfile=$(mktemp)

cleanup() {
  rm "$tmpfile"
}


echo 2>&1 "Getting assume-role credentials for $1"
if ! aws sts assume-role --role-session-name session1 --role-arn "$1" --output text | tail -n1 > "$tmpfile"; then
  echo 2>&1 "Error getting credentials"
  cleanup
  return 1
fi

echo 2>&1 "Setting environment variables for AWS session"
if AWS_ACCESS_KEY_ID=$(cut -f2 "$tmpfile") &&
    AWS_SECRET_ACCESS_KEY=$(cut -f4 "$tmpfile") &&
    AWS_SESSION_TOKEN=$(cut -f5 "$tmpfile"); then
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
  export AWS_SESSION_TOKEN
else
  cleanup
  return 1
fi

cleanup
