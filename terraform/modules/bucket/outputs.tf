output "arn" {
  description = "ARN for the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Bucket domain name. Will be of format 'bucketname.s3.amazonaws.com'."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "id" {
  description = "ID for the S3 bucket"
  value       = aws_s3_bucket.this.id
}
