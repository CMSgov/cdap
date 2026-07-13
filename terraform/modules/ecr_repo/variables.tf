variable "platform" {
  description = "Object representing the platform module."
  type = object({
    app               = string
    env               = string
    service           = string
    kms_alias_primary = object({ target_key_arn = string })
    primary_region    = object({ name = string })
    account_id        = string
  })
}

variable "service" {
  description = "Custom service name in case multiple ECR repos made in the same terraservice. If null, defaults to platform service value."
  type        = string
  default     = null
}

variable "repo_name_override" {
  description = "When possible, do not use. Override for the name of the ECR repository."
  type        = string
  default     = null
}

variable "default_retained_images" {
  description = "Number of images to retain. Recommended default is 3 (latest 3 releases) per platform container image policy."
  type        = number
  default     = 3

  validation {
    condition     = var.default_retained_images >= 1
    error_message = "Must retain at least 1 image to avoid service disruption during scaling events."
  }
}

variable "untagged_images_retained" {
  description = "Number of untagged images to retain before cleanup."
  type        = number
  default     = 10

  validation {
    condition     = var.untagged_images_retained >= 0
    error_message = "untagged_images_retained must be a non-negative number."
  }
}
