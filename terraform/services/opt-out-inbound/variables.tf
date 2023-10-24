variable "environment_name" {
  type        = string
  description = "The environment to target (dev, test, prod, sbx)"
}
variable "team_name" {
  description = "The name of the team (e.g., dpc or ab2d)"
  type        = string
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


variable "bfd_aws_account" {
  description = "BFD environment account number"
  type        = string
}

variable "env" {
  description = "environment associated to the bfd_env logic,either dev or test.If so,the result of condition is test; otherwise, it's prod"
  type        = string
}
