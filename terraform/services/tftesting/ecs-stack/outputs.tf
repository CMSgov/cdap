output "cluster_arn" {
  description = "ARN of the test ECS cluster"
  value       = aws_ecs_cluster.test.arn
}

output "service_connect_namespace" {
  value = aws_service_discovery_http_namespace.test
}
