output "name" {
  description = "Name for the lambda function"
  value       = aws_lambda_function.this.function_name
}

output "alias_arn" {
  description = "ARN of the live alias"
  value       = aws_lambda_alias.live.arn
}

output "function_version" {
  description = "Active S3 object version ID used for the Lambda deployment package"
  value = var.rollback_version != null ? var.rollback_version : (var.source_dir != null ?
  aws_s3_object.function_zip[0].version_id : var.source_code_version)
}

output "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the Lambda deployment package"
  value       = aws_lambda_function.this.source_code_hash
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
