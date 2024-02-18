variable "name" {
  description = "Name for the bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this bucket"
  type        = list
  default     = []
  sensitive   = true
}
