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
  default = "None"
}

variable "visibility_timeout_seconds" {
  description = "Queue visibility timeout in seconds"
  type        = number
  # Default is 900 to match default timeout in modules/function/variables.tf
  default = 900
}

variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}
