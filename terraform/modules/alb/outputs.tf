output "alb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB — use this for Route 53 alias records."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB — required for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS:443 listener. Listener can be used in downstream modules."
  value       = aws_lb_listener.https.arn
}

output "internal" {
  description = "Whether the ALB is internal (private) or internet-facing."
  value       = var.internal
}
