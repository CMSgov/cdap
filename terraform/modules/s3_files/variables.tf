variable "app" {
  description = "The application name (ab2d, bcda, bb, bfd, cdap, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "bb", "bfd", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, bb, bfd, cdap, or dpc."
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
  description = "Identifier suffix for the S3 Files resources (e.g. 'attribution-import-files')"
  type        = string
}

variable "bucket_id" {
  description = "Target S3 bucket ID/name to mount"
  type        = string
}

variable "bucket_arn" {
  description = "Target S3 bucket ARN to mount"
  type        = string
}

variable "kms_key_arn" {
  description = "Optional KMS Key ARN used for encryption at rest. If null, AWS managed encryption is used."
  type        = string
  default     = null
}

variable "read_only" {
  description = "Whether the file system access should enforce read-only operations. Defaults to true."
  type        = bool
  default     = true
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs permitted to mount the file system over NFS (TCP port 2049)"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "Optional VPC ID. When null, uses the shared CDAP vpc module."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Optional list of subnet IDs for mount targets. When null, uses the shared CDAP subnets module."
  type        = list(string)
  default     = null
}
