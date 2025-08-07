variable "vault_name" {
  description = "Name of the primary backup vault"
  type        = string
  default     = "CMS-CDAP-MANAGED_VAULT"
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test or prod."
  }
}

variable "backup_resources" {
  description = "List of resource ARNs to backup"
  type        = list(string)
  default = [
    "arn:aws:ec2:*:*:instance/*",
    "arn:aws:rds:*:*:db:*",
    "arn:aws:rds:*:*:cluster:*",
    "arn:aws:dynamodb:*:*:table/*",
    "arn:aws:elasticfilesystem:*:*:file-system/*"
  ]
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "example"
    Purpose     = "CrossRegionBackup"
  }
}
