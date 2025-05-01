variable "name" {
  description = "Name for the SNS topic"
  type        = string
}

variable "buckets" {
  description = "ARNs for S3 buckets that need to publish event notifications to the SNS topic"
  type        = list(any)
  default     = []
}
