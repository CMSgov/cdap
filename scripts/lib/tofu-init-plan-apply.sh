# Library to be sourced into scripts for running tofu init, plan, and apply
# in a GitHub Action.

echo "::group::$dir tofu"

if ! tofu init -reconfigure -backend-config="$repo_root/terraform/backends/${APP}-${ENV}.s3.tfbackend"; then
  job_error=true
  echo "::endgroup::"
  echo "::error::Error in tofu init for $dir"
  continue
fi

export TF_VAR_app="$APP"
export TF_VAR_env="$ENV"
tofu_warning=""
tofu_error=""
if tofu plan -detailed-exitcode -out "$temp_plan_out"; then
  echo "No changes planned for $dir"
elif [ "$?" -eq "2" ]; then # Detailed exit code is 2, meaning changes are planned
  tofu_warning="Changes planned for $dir"
else
  job_error=true
  tofu_error="Error in tofu plan for $dir"
fi

if [[ -n "$tofu_warning" && "$APPLY" == "true" ]]; then
  echo "Applying plan for $dir"
  if ! tofu apply "$temp_plan_out"; then
    job_error=true
    tofu_error="Error in tofu apply for $dir"
  fi
fi
echo "::endgroup::"

if [ -n "$tofu_warning" ]; then
  echo "::warning::$tofu_warning"
fi
if [ -n "$tofu_error" ]; then
  echo "::error::$tofu_error"
fi
