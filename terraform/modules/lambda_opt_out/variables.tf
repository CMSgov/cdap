variable "policy_name" {
  description = "Name of the IAM policy"
  type = string
}
variable "iam_role_name" {
  description = "Name of the IAM role"
  type   =  string
}
variable "function_name" {
  description = "Name of the lambda function"
  type = string
}

variable "role" {
  description = "ARN of the IAM role for the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Lambda function"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the Lambda function"
  type        = list(string)
}

variable "environment_variables" {
  description = "Map of environment variables for the Lambda function"
  type        = map(string)
}

variable "environment_name" {
  type        = string
  description = "The environment to target (dev,test,prod,sbx)"
}
variable "team_name" {
  description = "The name of the team (e.g., dpc or ab2d)"
  type        = string
}
variable "common_security_group_ids" {
  description = "Common security group IDs"
  type        = list(string)
}
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}
variable "vpc_subnet_security_group_service_name" {
  description = "service name for vpc, subnet, security group"
  type        = string
}
variable "s3_object_key" {
  description = "S3 key (object key or file name) for Lambda deployment package"
  type        = string
}
variable "s3_bucket" {
  description = "S3 key (object key or file name) for Lambda deployment package"
  type        = string
}
variable "account_number" {
  description = "AWS account number"
  type        = string
}
