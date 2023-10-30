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
  echo 2>&1 "Usage: source ${BASH_SOURCE:-${(%):-%x}} <account> <profile>"
  echo 2>&1 "Where <account> is the AWS account number and <profile> is the name"
  echo 2>&1 "of the profile with permanent creds in ~/.aws/credentials."
  return 1
fi

# Read input for MFA code
printf >&2 '%s ' 'Enter MFA code:'
read -r mfa_code

# Use default profile in ~/.aws/credentials if one is not specified
profile="${2:-default}"

tmpfile=$(mktemp)

cleanup() {
  rm "$tmpfile"
  unset mfa_code
  unset profile
  unset tmpfile
}

echo 2>&1 "Getting session token for profile $profile"
if ! aws --profile="$profile" sts get-session-token --serial-number \
    "arn:aws:iam::$1:mfa/app" --token-code "$mfa_code" > "$tmpfile"; then
  echo 2>&1 "Error getting session token"
  cleanup
  return 1
fi

echo 2>&1 "Setting environment variables for AWS session"
if AWS_ACCESS_KEY_ID="$(jq -r '.Credentials.AccessKeyId' "$tmpfile")" &&
    AWS_SECRET_ACCESS_KEY="$(jq -r '.Credentials.SecretAccessKey' "$tmpfile")" &&
    AWS_SESSION_TOKEN="$(jq -r '.Credentials.SessionToken' "$tmpfile")"; then
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
  export AWS_SESSION_TOKEN
else
  cleanup
  return 1
fi

echo 2>&1 "Session initialized for profile $profile"

cleanup
