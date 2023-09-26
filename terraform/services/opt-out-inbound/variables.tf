variable "environment_name" {
  type        = string
  description = "The environment to target (dev, test, prod, sbx)"
}
variable "team_name" {
  description = "The name of the team (e.g., dpc or ab2d)"
  type        = string
  default     = "dpc"
}
variable "account_number" {
  description = "AWS account number"
  type        = string
}
variable "lambda_handler" {
  description = "Lambda function handler"
  type        = string
}
variable "lambda_runtime" {
  description =  "lambda function runtime"
  type        = string
}

