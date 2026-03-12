output "this" {
  description = "The ecs cluster for the given inputs."
  value       = aws_ecs_cluster.this
}

output "service_connect_namespace_arn" {
  description = "ARN of the Cloud Map HTTP namespace for ECS Service Connect"
  value       = var.enable_service_connect ? aws_service_discovery_http_namespace.this[0].arn : null
}
