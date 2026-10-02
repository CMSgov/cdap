output "bucket_id" {
  description = "ID of the long-term log retention bucket"
  value       = module.log_bucket.id
}

output "bucket_arn" {
  description = "ARN of the long-term log retention bucket"
  value       = module.log_bucket.arn
}

output "kms_key_arn" {
  description = "ARN of the dedicated log encryption key"
  value       = aws_kms_key.log_retention.arn
}

output "firehose_arn" {
  description = "ARN of the log delivery Firehose stream"
  value       = aws_kinesis_firehose_delivery_stream.log_retention.arn
}

output "cloudwatch_to_firehose_role_arn" {
  description = "ARN of the role CloudWatch Logs subscription filters assume to write to the Firehose"
  value       = aws_iam_role.cloudwatch_to_firehose.arn
}
