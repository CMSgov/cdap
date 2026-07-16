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
}
