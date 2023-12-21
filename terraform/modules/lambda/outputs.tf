output "arn" {
  description = "ARN for the lambda"
  value = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name for the lambda function"
  value = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "ARN of the IAM role for the lambda"
  value       = aws_iam_role.lambda.arn
}

output "zip_file_bucket" {
  description = "Bucket name for the function.zip file"
  value       = aws_s3_bucket.lambda_zip_file.id
}
