variable "app" {
  description = "The application name (ab2d, bbapi, bcda, cdap dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bbapi", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bbapi, bcda, cdap or dpc."
  }
}

variable "env" {
  description = "Deployment environment (dev, test, sandbox, stage, prod)"
  type        = string
}

variable "monitor_config" {
  description = "Fully merged monitor configuration. All values required; use defaults.yml as the baseline."
  type = object({
    enabled = object({
      ecs    = bool
      sqs    = bool
      sns    = bool
      lambda = bool
      s3     = bool
    })
    ecs = object({
      cpu_threshold    = number
      memory_threshold = number
    })
    sqs = object({
      dlq_message_threshold   = number
      max_message_age_seconds = number
    })
    sns = object({
      failed_notification_threshold = number
    })
    lambda = object({
      error_rate_threshold      = number
      throttle_threshold        = number
      duration_p99_threshold_ms = number
    })
    s3 = object({
      error_threshold_4xx = number
      error_threshold_5xx = number
    })
  })
}

variable "notify" {
  description = "Composed notification string — all @mention handles joined with spaces"
  type        = string
}
