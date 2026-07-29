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

output "security_group_id" {
  value       = local.managed_sg ? aws_security_group.alb[0].id : null
  description = <<-EOT
    ID of the module-managed ALB security group.
    Null when security_group_ids are provided externally.
    Use this in the caller terraservice to wire egress rules from the ALB
    to ECS task security groups:

    resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
      security_group_id            = module.alb.security_group_id
      referenced_security_group_id = module.ecs_service.task_security_group_id
      from_port                    = 8443
      to_port                      = 8443
      ip_protocol                  = "tcp"
    }
  EOT
}

output "internal" {
  description = "Whether the ALB is internal (private) or internet-facing."
  value       = var.internal
}
