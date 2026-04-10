locals {
  _latest_cert_version = var.public_domain_name != null ? max(var.public_certificate_versions...) : null

  csr_instructions = var.public_domain_name != null ? join("\n", [
    "Latest CSR version: ${local._latest_cert_version}",
    "",
    "SSM path:",
    "  /${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${local._latest_cert_version}/csr",
    "",
    "To retrieve and zip for CMS submission:",
    "  aws ssm get-parameter \\",
    "    --name \"/${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${local._latest_cert_version}/csr\" \\",
    "    --query \"Parameter.Value\" \\",
    "    --output text > ${var.public_domain_name}.csr",
    "  zip ${var.public_domain_name}-v${local._latest_cert_version}-csr.zip ${var.public_domain_name}.csr",
    "",
    "After CMS signs the certificate, store the values via SOPS and re-apply.",
  ]) : null
}

output "private_certificate_arn" {
  description = "ARN of the PCA-issued certificate covering the internal and/or zscaler domains. Use as the primary cert on the ALB HTTPS listener."
  value       = (var.enable_internal_endpoint || var.enable_zscaler_endpoint) ? aws_acm_certificate_validation.private[0].certificate_arn : null
  sensitive   = true
}

output "internal_domain" {
  value = var.enable_internal_endpoint ? local.internal_domain : null
}

output "zscaler_domain" {
  value = var.enable_zscaler_endpoint ? local.zscaler_domain : null
}

output "public_certificate_arn" {
  description = "ARN of the imported CMS-signed public certificate. Null if cert values have not yet been provided."
  value       = (var.public_domain_name != null && var.public_certificate != null && var.public_private_key != null) ? aws_acm_certificate.public[0].arn : null
  sensitive   = true
}

output "csr_retrieval_instructions" {
  description = "Instructions for retrieving the latest CSR and submitting to CMS."
  value       = local.csr_instructions
}
