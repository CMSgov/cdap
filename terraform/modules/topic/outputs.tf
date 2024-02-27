output "arn" {
  description = "ARN for the SNS topic"
  value       = aws_sns_topic.this.arn
}
