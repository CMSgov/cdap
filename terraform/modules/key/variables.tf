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
  type        = list
  default     = []
}
