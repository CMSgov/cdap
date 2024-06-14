variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list
  default     = []
}

variable "access_log_bucket_name" {
  type = string
  description = "The name of the centralized access log bucket"
  default = "access-logs"
}
