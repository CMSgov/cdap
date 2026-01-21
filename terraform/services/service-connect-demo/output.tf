# ===========================
# Outputs
# ===========================

output "backend_service_name" {
  description = "Backend service name"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Frontend service name"
  value       = aws_ecs_service.frontend.name
}

output "alb_dns_name" {
  description = "ALB DNS name for external access"
  value       = aws_lb.frontend.dns_name
}

output "service_connect_endpoint" {
  description = "Internal Service Connect endpoint for backend"
  value       = "http://backend:80"
}


# ===========================
# Outputs
# ===========================

output "frontend_alb_dns" {
  description = "DNS name of the frontend ALB"
  value       = aws_lb.frontend.dns_name
}
