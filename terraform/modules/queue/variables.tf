variable "name" {
  description = "Name for the queue"
  type        = string
}

variable "function_name" {
  description = "Name of the lambda function to trigger"
  type        = string
  default     = ""
}

variable "lambda_event_enabled" {
  description = "Whether the aws_lambda_event_source_mapping is enabled"
  type        = bool
  default     = true
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
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, cdap or dpc."
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

variable "policy_documents" {
  description = "List of IAM policy documents that are merged together into the exported document. Statements must have unique `sid`s"
  type        = list(string)
  default     = []
}
