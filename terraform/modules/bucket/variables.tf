variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list(any)
  default     = []
}

variable "legacy" {
  description = "Is this deployment in the greenfield environment (false)?"
  type        = bool
  default     = true
}
