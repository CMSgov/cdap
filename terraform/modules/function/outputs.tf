output "name" {
  description = "Name for the lambda function"
  value = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "ARN of the IAM role for the function"
  value       = aws_iam_role.function.arn
}

output "zip_bucket" {
  description = "Bucket name for the function.zip file"
  value       = module.zip_bucket.id
}

output "security_group_id" {
  description = "ID for the security group for the function"
  value       = aws_security_group.function.id
}
