variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, or prod."
  }
}

variable "function_name" {
  description = "Name of the lambda function"
  type        = string
}

variable "function_description" {
  description = "Description of the lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "lambda_handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "lambda_role_inline_policies" {
  description = "Inline policies (in JSON) for the lambda IAM role"
  type        = map(string)
  default     = {}
}

variable "security_group_ids" {
  description = "List of security group IDs for the Lambda function"
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Map of environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "promotion_roles" {
  description = "List of ARNs to allow access for deploy roles to promote lambda zip files to upper environments"
  type        = list(string)
  default     = []
}

variable "create_function_zip" {
  description = "Create the function zip file, necessary for initialization (defaults to true)"
  type        = bool
  default     = true
}
