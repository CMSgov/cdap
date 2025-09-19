output "service" {
  description = "The ecs service for the given inputs."
  value       = aws_ecs_service.this
}

output "task_definition" {
  description = "The ecs task definition for the given inputs."
  value       = aws_ecs_task_definition.this
}

