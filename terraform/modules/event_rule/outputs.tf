output "arn" {
  description = "ARN of the EventBridge rule. Use it in SNS or SQS resource policies as the aws:SourceArn condition."
  value       = aws_cloudwatch_event_rule.this.arn
}

output "name" {
  description = "Name of the EventBridge rule."
  value       = aws_cloudwatch_event_rule.this.name
}

output "target_ids" {
  description = "Target IDs attached to the rule, keyed the same as var.targets."
  value       = { for k, t in aws_cloudwatch_event_target.this : k => t.target_id }
}
