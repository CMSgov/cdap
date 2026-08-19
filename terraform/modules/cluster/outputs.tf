output "this" {
  description = "The ecs cluster for the given inputs."
  value       = aws_ecs_cluster.this
}

output "service_discovery_namespace" {
  description = "Namespace to be used for service connections in this cluster"
  value       = var.supports_service_connect ? aws_service_discovery_http_namespace.this[0] : null
}
