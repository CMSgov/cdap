output "service" {
  description = "The ECS service resource."
  value       = aws_ecs_service.this
}

output "ecs_service_name" {
  description = "Full name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "full_name_override" {
  description = "Full name of the ECS service."
  value       = local.service_name_full
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

output "task_security_group_id" {
  description = "ID of the ECS task security group (module-managed or first caller-provided)."
  value       = (length(var.security_groups) == 0) ? aws_security_group.task[0].id : var.security_groups[0]
}

output "task_role_arn" {
  description = "ARN of the ECS task role (module-managed or externally provided)."
  value       = aws_iam_role.task.arn
}

output "service_connect_port" {
  description = "Port clients should use when calling this service via Service Connect."
  value = var.enable_ecs_service_connect ? coalesce(
    var.service_connect_client_port,
    local.sc_port_name != null ? try(local.port_map[local.sc_port_name], null) : null
  ) : null
}

output "service_connect_name" {
  description = "Short DNS name for this service within the Service Connect namespace. Other services call this service at http://<service_connect_name>:<service_connect_port>/."
  value       = var.enable_ecs_service_connect ? local.service_name : null
}

output "service_connect_endpoint" {
  description = "Full Service Connect endpoint for this service (e.g. http://api:8080). Null if Service Connect is not enabled."
  value = var.enable_ecs_service_connect ? format(
    "http://%s:%d",
    local.service_name,
    coalesce(
      var.service_connect_client_port,
      local.sc_port_name != null ? try(local.port_map[local.sc_port_name], null) : null
    )
  ) : null
}
