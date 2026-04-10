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

output "all_listener_arns" {
  description = <<-EOT
    Map of (string) to listener ARNs, including the default 443 listener.
    Use this in ecs-service module calls:
      alb_listener_arn = module.my_alb.all_listener_arns["9900"]
  EOT
  value = merge(
    { "443" = aws_lb_listener.https.arn },
    {
      for port, listener in aws_lb_listener.extra_https :
      port => listener.arn
    }
  )
}

output "internal" {
  description = "Whether the ALB is internal (private) or internet-facing."
  value       = var.internal
}
