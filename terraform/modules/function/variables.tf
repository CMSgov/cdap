variable "name" {
  description = "Name of the lambda function"
  type        = string
}

variable "description" {
  description = "Description of the lambda function"
  type        = string
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type = object({
    app               = string
    env               = string
    kms_alias_primary = object({ target_key_arn = string })
    primary_region    = object({ name = string })
    account_id        = string
  })
}

# ── Core Function Config

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "function_handler"
}

variable "architecture" {
  description = "Lambda function CPU architecture. Use arm64 for Graviton (better price/performance for most workloads)."
  type        = string
  default     = "x86_64"
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Valid value for architecture is x86_64 or arm64"
  }
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda function timeout"
  type        = number
  default     = 900
}

variable "memory_size" {
  description = "Lambda function memory size"
  type        = number
  default     = null
}

# ── Source / Deployment ───────────────────────────────────────────────────────

variable "source_dir" {
  description = "Path to the Lambda source directory to zip and upload. If set, the module manages zipping and deployment. If null, an external process (or dummy zip) is used."
  type        = string
  default     = null
}

variable "source_dir_excludes" {
  description = "List of glob (**/*) patterns to exclude when zipping the source directory."
  type        = list(string)
  default     = []
}

variable "source_code_version" {
  description = "Optional S3 object version of function.zip uploaded to module's zip_bucket by external sources."
  type        = string
  default     = null
}

variable "liveness_check_enabled" {
  description = <<-EOT
    Enables a deploy-time liveness check that invokes the Lambda function
    immediately after deployment to verify it is healthy and correctly configured.

    When enabled, an aws_lambda_invocation resource is created that sends a
    { "RequestType": "LivenessCheck" } payload to the Lambda function after
    each deployment. The invocation is re-triggered whenever the Lambda source
    code changes (tracked via source_code_hash).

    The Lambda function is responsible for implementing the liveness check logic
    in its handler. This may include verifying external dependencies, validating
    configuration, checking connectivity to downstream services, or any other
    health validation relevant to the function's purpose.

    If the liveness check fails, the Lambda should raise an exception. This
    surfaces as a function error and causes the Tofu apply to fail, alerting
    the deploying team immediately.

    Recommended: true in all environments to catch misconfiguration at deploy time.
    EOT
  type        = bool
  default     = true
}

variable "rollback_version" {
  description = <<-EOT
    S3 object version ID of a previous "function.zip" to roll back to.
    When null (default), Lambda uses the latest version of function.zip.
    When set, Lambda is pinned to that specific S3 object version.

    To list available version IDs:
      aws s3api list-object-versions \
        --bucket <zip_bucket_name> \
        --prefix function.zip \
        --query 'Versions[*].{VersionId:VersionId, LastModified:LastModified}'
  EOT
  type        = string
  default     = null
}

# ── Runtime Behavior ──────────────────────────────────────────────────────────

variable "environment_variables" {
  description = "Map of environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "Cron or rate expression for a scheduled function"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda function logs in CloudWatch. If null, no retention policy is set and retention is managed externally (e.g., via cdap/scripts/set_log_retention/)."
  type        = number
  default     = 180
}

# ── IAM / Permissions ─────────────────────────────────────────────────────────
variable "ssm_parameter_paths" {
  description = <<-EOT
    List of SSM parameter paths this function is permitted to read.
    Each entry must be a path starting with '/' (e.g., /cdap/test/lambda/secret).
    The module will validate that each parameter exists and construct the ARN automatically.
    If empty (default), the function receives no SSM access.
    Scope each entry to the specific parameters this function requires.
  EOT
  type        = list(string)
  default     = []

}

variable "function_role_inline_policies" {
  description = "Inline policies (in JSON) for the function IAM role"
  type        = map(string)
  default     = {}
}

# ── Advanced / Migration strategies ─────────────────────────────────────────────────

variable "additional_admin_role_arns" {
  description = "List of additional IAM role arns to allow assume role"
  type        = list(string)
  default     = []
}

variable "extra_kms_key_arns" {
  description = "Optional list of additional KMS key ARNs the Lambda can use"
  type        = list(string)
  default     = []
}

variable "layer_arns" {
  description = "Optional list of layer arns"
  type        = list(string)
  default     = []
}

variable "github_actions_repos" {
  description = <<-EOT
    List of GitHub repository paths (e.g. "org/repo") that are permitted to
    deploy Lambda function zips to this module's S3 bucket via GitHub Actions
    OIDC. When non-empty, an S3 bucket policy is added that allows the
    corresponding GitHub Actions IAM role to put/get objects under the
    function zip key.

    Example:
      github_actions_repos = ["CMSgov/bcda-app", "CMSgov/dpc-app"]

    Leave empty ([]) to disable CI/CD write access to the bucket entirely.
  EOT
  type        = list(string)
  default     = []
}

variable "dd_python_layer_version" {
  description = "Version number for Datadog's Python Lambda layer. Required if using a python runtime."
  type        = number
  default     = 125
}

variable "dd_node_layer_version" {
  description = "Version number for Datadog's Node.js Lambda layer. Required if using a Node.js runtime."
  type        = number
  default     = 137
}

variable "dd_java_layer_version" {
  description = "Version number for Datadog's Java Lambda layer. Required if using a Java runtime."
  type        = number
  default     = 26
}

variable "dd_ruby_layer_version" {
  description = "Version number for Datadog's Ruby Lambda layer. Required if using a Ruby runtime."
  type        = number
  default     = 28
}

variable "dd_dotnet_layer_version" {
  description = "Version number for Datadog's .NET Lambda layer. Required if using a .NET runtime."
  type        = number
  default     = 24
}
