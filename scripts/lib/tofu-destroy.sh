# Library to be sourced into scripts for running tofu destroy
# in a GitHub Action.

echo "::group::$dir tofu destroy"

export TF_VAR_app="$APP"
export TF_VAR_env="$ENV"
tofu_warning=""
tofu_error=""

echo "Removing resources for $dir"
if ! tofu destroy -auto-approve; then
  job_error=true
  tofu_error="Error in tofu apply for $dir"
fi

echo "::endgroup::"

if [ -n "$tofu_warning" ]; then
  echo "::warning::$tofu_warning"
fi
if [ -n "$tofu_error" ]; then
  echo "::error::$tofu_error"
fi
