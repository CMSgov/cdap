variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test,sandbox, or prod."
  }
}

variable "name" {
  description = "Name for the S3 bucket"
  type        = string
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
