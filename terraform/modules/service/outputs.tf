output "service" {
  description = "The ECS service resource."
  value       = aws_ecs_service.this
}

output "ecs_service_name" {
  description = "Full name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "ecs_service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.this.id
}

output "task_definition" {
  description = "The ECS task definition resource."
  value       = aws_ecs_task_definition.this
}

output "target_group_arn" {
  description = "ARN of the ALB target group (if ALB integration is enabled)."
  value       = local.enable_alb_integration ? aws_lb_target_group.this[0].arn : null
}

output "listener_rule_arn" {
  description = "ARN of the ALB listener rule (if ALB integration is enabled)."
  value       = local.enable_alb_integration ? aws_lb_listener_rule.this[0].arn : null
}

output "service_connect_role_arn" {
  description = "ARN of the Service Connect IAM role (if Service Connect is enabled)."
  value       = var.enable_ecs_service_connect ? aws_iam_role.service_connect[0].arn : null
}
