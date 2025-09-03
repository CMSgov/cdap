variable "name" {
  description = "Name for the SNS topic"
  type        = string
}

variable "publisher_arns" {
  description = "ARNs for S3 buckets or services that need to publish event notifications to the SNS topic"
  type        = list(any)
  default     = []
}

variable "policy_service_identifiers" {
  description = "Identifier(s) for service principals for use in policy. Example:  s3.amazonaws.com"
  type        = list(any)
  default     = ["s3.amazonaws.com"]
}
