output "arn" {
  description = "ARN for the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "id" {
  description = "ID for the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "access_log_bucket_name" {
  description = "The name of the access log S3 bucket"
  value       = data.aws_s3_bucket.access_logs.bucket
}

output "access_log_bucket_arn" {
  description = "The ARN of the access log S3 bucket"
  value       = data.aws_s3_bucket.access_logs.arn
}
