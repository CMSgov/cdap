# -------------------------------------------------------
# ALB
# -------------------------------------------------------
output "alb_arn" {
  value = var.create_alb ? aws_lb.this[0].arn : null
}

output "alb_dns_name" {
  value = var.create_alb ? aws_lb.this[0].dns_name : null
}

output "alb_zone_id" {
  value = var.create_alb ? aws_lb.this[0].zone_id : null
}

output "alb_arn_suffix" {
  description = "Used for CloudWatch metric dimensions / WAF association."
  value       = var.create_alb ? aws_lb.this[0].arn_suffix : null
}

output "alb_security_group_id" {
  value = (var.create_alb && local.managed_sg) ? aws_security_group.alb[0].id : null
}

# -------------------------------------------------------
# Listeners
# -------------------------------------------------------
output "https_listener_arns" {
  description = "Map of listener port => ARN, for ecs-service's var.alb_listener_arn."
  value       = { for k, l in aws_lb_listener.https : k => l.arn }
}

output "http_listener_arn" {
  value = var.create_alb ? aws_lb_listener.http[0].arn : null
}

# -------------------------------------------------------
# Route53
# -------------------------------------------------------
output "internal_dns_record_fqdn" {
  description = "FQDN of the internal.cms.gov alias record, if created."
  value       = var.create_internal_dns_record != null ? aws_route53_record.internal_alb[0].fqdn : null
}

output "zscaler_dns_record_fqdn" {
  description = "FQDN of the cmscloud.local alias record, if created."
  value       = var.create_zscaler_dns_record ? aws_route53_record.zscaler_alb[0].fqdn : null
}

# -------------------------------------------------------
# NLB / PrivateLink
# -------------------------------------------------------
output "nlb_arn" {
  description = "Pass to ecs-service's future enable_nlb_integration when nlb_mode = \"direct\"."
  value       = var.create_nlb ? aws_lb.network[0].arn : null
}

output "nlb_dns_name" {
  value = var.create_nlb ? aws_lb.network[0].dns_name : null
}

output "nlb_zone_id" {
  value = var.create_nlb ? aws_lb.network[0].zone_id : null
}

output "nlb_security_group_id" {
  value = var.create_nlb ? aws_security_group.nlb[0].id : null
}

output "privatelink_service_name" {
  description = "Service name consumers reference in their aws_vpc_endpoint. Null unless enable_privatelink is true."
  value       = var.enable_privatelink ? aws_vpc_endpoint_service.this[0].service_name : null
}
