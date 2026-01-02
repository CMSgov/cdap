variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
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
  description = <<EOT
    Full name for the S3 bucket.
    Full readable string for pre-existing buckets or
    those that don't follow convention. Prioritized name value.
  EOT
  type        = string
  default     = null

  validation {
    # Check if either this variable is true OR bucket_common_name is not null
    condition     = var.name != null || var.bucket_common_name != null
    error_message = "You must provide a value for 'name' or 'common_name'."
  }
}

variable "common_name" {
  description = <<EOT
    Common readable string name to which a standard
    prefix is added using app and env. Preferred for convention
  EOT
  type        = string
  default     = null

  validation {
    # Check if either this variable is true OR bucket_common_name is not null
    condition     = var.bucket_name != null || var.name != null
    error_message = "You must provide a value for 'name' or 'common_name'."
  }
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list(any)
  default     = []
}

variable "ssm_parameter" {
  description = "SSM Parameter path for bucket output"
  type        = string
  default     = null
}

variable "create_write_policy" {
  description = <<EOT
    When true, will generate a policy allowing writing objects to the bucket.
    Use with aws_iam_role_policy_attachment to grant access to resources in other modules
   EOT
  type        = bool
  default     = false
}

variable "create_read_policy" {
  description = <<EOT
    When true, will generate a policy allowing reading objects from the bucket.
    Use with aws_iam_role_policy_attachment to grant access to resources in other modules
   EOT
  type        = bool
  default     = false
}

variable "create_delete_policy" {
  description = <<EOT
  When true, will generate a policy allowing deletion of objects from the bucket.\n
    Use with aws_iam_role_policy_attachment to grant access to resources in other modules.
  EOT
  type        = bool
  default     = false
}
