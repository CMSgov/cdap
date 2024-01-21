variable "name" {
  description = "Name for the queue"
  type        = string
}

variable "function_name" {
  description = "Name of the lambda function to trigger"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to subscribe to"
  type        = string
  # Setting default to "None" allows us to set the AWS Parameter Store value
  # to "None" to disable creation of SNS Topic Subscription
  default     = "None"
}
