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

variable "service" {
  description = "Custom service name in case multiple ECR repos made in the same terraservice. If null, defaults to platform service value."
  type        = string
  default     = null
}

variable "repo_name_override" {
  description = "When possible, do not use. Override for the name of the ecr repository."
  type        = string
  default     = null
}

variable "num_retained_images" {
  description = "Prefer this default for prod account. The number of images retained in the ECR repository."
  type        = number
  default     = 5
}
