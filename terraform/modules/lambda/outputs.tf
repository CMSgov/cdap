output "lambda_role_arn" {
  description = "ARN of the IAM role for the lambda"
  value       = aws_iam_role.lambda.arn
}

output "lambda_zip_file_bucket" {
  description = "Bucket name for the function.zip file"
  value       = aws_s3_bucket.lambda_zip_file.id
}
