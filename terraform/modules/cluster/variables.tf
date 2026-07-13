variable "platform" {
  description = "Object that describes standardized platform values."
  type = object({
    app = string,
    env = string,
    kms_alias_primary = object({
      target_key_arn = string
    }),
    service          = string,
    is_ephemeral_env = string
  })
}

variable "cluster_name_override" {
  description = "Name of the ecs cluster."
  type        = string
  default     = null
}

variable "log_retention_days" {
  type        = number
  default     = 180
  description = "Number of days to retain ECS task logs in CloudWatch. Required for production is minimum 180."

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
      1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be a value supported by CloudWatch Logs (e.g. 30, 90, 180, 365, 731). See: https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html"
  }
}
