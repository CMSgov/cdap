variable "aws_region" {
description = "AWS region"
type        = string
default     = "us-east-1"
}

variable "private_subnet_ids" {
description = "List of private subnet IDs for ECS tasks"
type        = list(string)
}

variable "public_subnet_ids" {
description = "List of private subnet IDs for ECS tasks"
type        = list(string)
}

variable "vpc_id" {
description = "VPC ID where ECS cluster will be deployed"
type        = string
}
