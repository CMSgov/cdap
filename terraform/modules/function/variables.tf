variable "app" {
  description = "The application name (ab2d, bcda, cdap dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, cdap or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}

variable "name" {
  description = "Name of the lambda function"
  type        = string
}

variable "description" {
  description = "Description of the lambda function"
  type        = string
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
  description = "Pin the live alias to a specific version for rollback. Set to null for normal deploys (alias tracks latest published version)."
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
    List of SSM parameter ARNs or path patterns this function is permitted to read.
    Each entry should be a full ARN or ARN pattern. This can be retrieved from platform.module.ssm.ssm_root_name.parameter_name.arn.
    If empty (default), the function receives no SSM access.
    Do not use broad wildcards — scope each entry to the specific parameters this function requires.
  EOT
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for arn in var.ssm_parameter_paths :
      can(regex("^arn:aws:ssm:", arn))
    ])
    error_message = "Each entry in ssm_parameter_paths must be a valid SSM parameter ARN starting with 'arn:aws:ssm:'."
  }
}

variable "function_role_inline_policies" {
  description = "Inline policies (in JSON) for the function IAM role"
  type        = map(string)
  default     = {}
}

# ── Advanced / Migration strategies ─────────────────────────────────────────────────

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
