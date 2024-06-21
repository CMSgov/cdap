variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list(any)
  default     = []
}

variable "app" {
  description = "The name of the application"
  type        = string
}

variable "env" {
  description = "The environment name"
  type        = string
}
