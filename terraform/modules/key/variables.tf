variable "name" {
  description = "Name (alias) for the KMS key"
  type        = string
}

variable "description" {
  description = "Description for the KMS key"
  type        = string
  default     = null
}

variable "sns_topics" {
  description = "ARNs for SNS topics that need to write messages to an SQS queue encrypted by this key"
  type        = list(any)
  default     = []
}

variable "buckets" {
  description = "ARNs for S3 buckets that need to publish event notifications to an SNS topic encrypted by this key"
  type        = list(any)
  default     = []
}

variable "user_roles" {
  description = "ARNs for roles (generally in other accounts) that will use this key"
  type        = list(any)
  default     = []
}
