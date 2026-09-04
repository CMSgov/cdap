variable "additional_bucket_policies" {
  default     = []
  description = "A list of additional bucket policies to be merged with the default."
  type        = list(string)
}

variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "bb", "bfd", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
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

variable "env" {
  description = "The application environment (dev, test, sandbox, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, prod, or mgmt."
  }
}

variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "ssm_parameter" {
  description = "SSM Parameter path for bucket output"
  type        = string
  default     = null
}
