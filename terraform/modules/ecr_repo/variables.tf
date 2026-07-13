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

variable "tag_rules" {
  description = <<-EOT
    List of lifecycle rules for images, applied in priority order.
    Supports both count-based and time-based expiry per rule.

    count_type options:
      - "imageCountMoreThan" (default): retain up to `retained_images` images
      - "sinceImagePushed": expire images older than `expiry_days` days

    A null tag_prefix produces a catch-all rule (tagStatus: any).

    Default: keep last 3 images (all tags) per platform policy.

    Example — multiple tag classes in one repo:
      tag_rules = [
        { tag_prefix = "rls-r", count_type = "imageCountMoreThan", retained_images = 5,  description = "Keep last 5 release images" },
        { tag_prefix = "temp-", count_type = "imageCountMoreThan", retained_images = 3,  description = "Keep last 3 temp images" },
        { tag_prefix = null,    count_type = "sinceImagePushed",   expiry_days     = 14, description = "Expire all other images older than 14 days" },
      ]
  EOT
  type = list(object({
    tag_prefix      = optional(string)
    count_type      = optional(string, "imageCountMoreThan")
    retained_images = optional(number)
    expiry_days     = optional(number)
    description     = optional(string)
  }))
  default = [
    {
      tag_prefix      = null
      count_type      = "imageCountMoreThan"
      retained_images = 3
      description     = "Keep last 3 images (platform policy default)"
    }
  ]

  validation {
    condition     = length(var.tag_rules) >= 1
    error_message = "At least one tag rule must be defined."
  }

  validation {
    condition = alltrue([
      for r in var.tag_rules :
        contains(["imageCountMoreThan", "sinceImagePushed"], coalesce(r.count_type, "imageCountMoreThan"))
    ])
    error_message = "count_type must be either 'imageCountMoreThan' or 'sinceImagePushed'."
  }

  validation {
    condition = alltrue([
      for r in var.tag_rules :
        (coalesce(r.count_type, "imageCountMoreThan") == "imageCountMoreThan" && r.retained_images != null) ||
        (r.count_type == "sinceImagePushed" && r.expiry_days != null)
    ])
    error_message = "Each rule must provide retained_images for imageCountMoreThan, or expiry_days for sinceImagePushed."
  }

  validation {
    condition = alltrue([
      for r in var.tag_rules :
        r.retained_images == null || r.retained_images >= 1
    ])
    error_message = "retained_images must be at least 1 to prevent service disruption during scaling events."
  }

  validation {
    condition = alltrue([
      for r in var.tag_rules :
        r.expiry_days == null || (r.expiry_days >= 1 && r.expiry_days <= 60)
    ])
    error_message = "expiry_days must be between 1 and 60 per platform container image policy."
  }
}

variable "untagged_expiry_days" {
  description = <<-EOT
    Number of days after which untagged images are expired.
    Defaults to 30 days per platform policy (max 30-60 day retention guidance).
    Untagged images are always cleaned up as the lowest priority rule.
  EOT
  type    = number
  default = 30

  validation {
    condition     = var.untagged_expiry_days >= 1 && var.untagged_expiry_days <= 60
    error_message = "untagged_expiry_days must be between 1 and 60 per platform container image policy."
  }
}
