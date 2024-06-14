variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list
  default     = []
}

variable "app" {
  description = "The application name (bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["bcda", "dpc"], var.app)
    error_message = "Valid value for app is bcda, or dpc."
  }
}
