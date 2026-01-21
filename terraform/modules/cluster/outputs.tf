output "this" {
  description = "The ecs cluster for the given inputs."
  value       = aws_ecs_cluster.this
}

output "service_connect_namespace" {
  description = "The Service Connect discovery namespace."
  value = aws_service_discovery_http_namespace.ecs-service-discovery
}
