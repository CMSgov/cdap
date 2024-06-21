output "access_log_bucket_name" {
  description = "The name of the S3 bucket used for access logs"
  value       = aws_s3_bucket.bucket-access_logs.bucket
}

output "access_log_bucket_arn" {
  description = "The ARN of the S3 bucket used for access logs"
  value       = aws_s3_bucket.bucket-access_logs.arn
}
