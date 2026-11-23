output "pattern_rule_arn" {
  description = "ARN of the event-pattern test rule, when enabled"
  value       = try(module.pattern_rule[0].arn, null)
}

output "schedule_rule_arn" {
  description = "ARN of the schedule test rule, when enabled"
  value       = try(module.schedule_rule[0].arn, null)
}
