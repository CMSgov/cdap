output "aws_ecs_service" {
  description = "The ecs service for the given inputs."
  value       = aws_ecs_service.this
}

output "aws_ecs_task_definition" {
  description = "The ecs task definition for the given inputs."
  value       = aws_ecs_task_definition.this
}

