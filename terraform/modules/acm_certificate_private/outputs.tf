output "private_cert_arn" {
  description = "ARN of the PCA-issued certificate covering the internal and/or zscaler domains. Use as the primary cert on the ALB HTTPS listener."
  value       = aws_acm_certificate.private.arn
  sensitive   = true
}

output "internal_domain" {
  value       = local.enable_internal_endpoint ? local.internal_domain : null
  description = "FQDN of the internal endpoint. Use this as the Route 53 record name for DNS record to match exactly."
}

output "zscaler_domain" {
  value = var.enable_zscaler_endpoint ? local.zscaler_domain : null
}
