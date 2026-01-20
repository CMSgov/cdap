# ===========================
# Outputs
# ===========================

output "cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.main.name
}

output "namespace_arn" {
  description = "Service Connect namespace ARN"
  value       = aws_service_discovery_http_namespace.service_connect.arn
}

output "namespace_name" {
  description = "Service Connect namespace name"
  value       = aws_service_discovery_http_namespace.service_connect.name
}

output "backend_service_name" {
  description = "Backend service name"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Frontend service name"
  value       = aws_ecs_service.frontend_with_alb.name
}

output "alb_dns_name" {
  description = "ALB DNS name for external access"
  value       = aws_lb.frontend.dns_name
}

output "service_connect_endpoint" {
  description = "Internal Service Connect endpoint for backend"
  value       = "http://backend:80"
}
