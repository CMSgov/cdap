output "arn" {
  description = "ARN for the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "id" {
  description = "ID for the S3 bucket"
  value       = aws_s3_bucket.this.id
}
