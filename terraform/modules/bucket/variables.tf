variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  default     = null
  description = "Use sparingly. The ARN of a custom S3 bucket encryption key used for this bucket."
  type        = string
}

variable "use_custom_kms_key" {
  description = "Set true when kms_key_arn is provided, even if its value isn't known until apply."
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Whether to allow Terraform to destroy this bucket even if it contains objects. Defaults to true to match existing behavior; set to false for buckets holding data you don't want accidentally wiped (e.g. cross-account export buckets)."
  type        = bool
  default     = true
}

variable "ssm_parameter" {
  description = "SSM Parameter path for bucket output"
  type        = string
  default     = null
}
variable "additional_bucket_policies" {
  default     = []
  description = "A list of additional bucket policies to be merged with the default."
  type        = list(string)
}

variable "platform" {
  description = "Object representing the CDAP platform module. Provides the app and environment names and the account's primary KMS key for encrypting the access-logging log group."
  type = object({
    app               = string
    env               = string
    kms_alias_primary = object({ target_key_arn = string })
  })
}

variable "access_logging" {
  description = "external is reserved for the 701-log-retention bucket only. Server access log delivery route. cloudwatch (the default) delivers through a per-bucket CloudWatch log group and the shared log-retention Firehose into the log-retention bucket. 701-log-retention bucket must log directly to the CMS bucket to avoid looping its own access logs back into itself. Do not use external for any other bucket."
  type        = string
  default     = "cloudwatch"
  validation {
    condition     = contains(["external", "cloudwatch"], var.access_logging)
    error_message = "Valid values for access_logging are cloudwatch or external which is reserved for the 701-log-retention bucket."
  }
}

variable "object_lock" {
  description = "S3 Object Lock (WORM) default retention. Object Lock can only be enabled at bucket creation. Mode is GOVERNANCE or COMPLIANCE."
  type = object({
    mode  = string
    years = number
  })
  default = null
}

variable "transitions" {
  description = "Storage class transitions for current object versions. This is used currently in the long-term-log-retention bucket for cost savings on long-lived log objects for HIPAA compliance."
  type = list(object({
    days          = number
    storage_class = string
  }))
  default = []
}

variable "expiration_days" {
  description = "Days after object creation when current versions expire and noncurrent versions are permanently deleted. Must exceed any Object Lock retention period."
  type        = number
  default     = null
}

# modules/bucket/variables.tf
variable "additional_bucket_statements" {
  description = "Structured statements that will reference the bucket's ARN. Useful for iterative calls of the module."
  type = list(object({
    sid        = string
    principals = list(string)
    actions    = list(string)
  }))
  default = []
}
