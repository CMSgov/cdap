locals {
  public_versions_as_strings = var.public_domain_name != null ? [for v in var.public_certificate_versions : tostring(v)] : []

  _latest_cert_version = var.public_domain_name != null ? max(var.public_certificate_versions...) : null

  # Versions that have signed material but have NOT yet been imported into ACM
  # these are the ones still awaiting a CMS-signed response.
  _pending_versions = [
    for v in local.public_versions_as_strings : v
    if lookup(var.public_certificate, v, null) == null || lookup(var.public_private_key, v, null) == null
  ]

  csr_instructions = var.public_domain_name != null ? join("\n", flatten([
    for v in local._pending_versions : [
      "Version ${v} — awaiting CMS signature",
      "",
      "SSM path:",
      "  /${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${v}/csr",
      "",
      "To retrieve and zip for CMS submission:",
      "  aws ssm get-parameter \\",
      "    --name \"/${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${v}/csr\" \\",
      "    --query \"Parameter.Value\" \\",
      "    --output text > ${var.public_domain_name}-v${v}.csr",
      "  zip ${var.public_domain_name}-v${v}-csr.zip ${var.public_domain_name}-v${v}.csr",
      "",
      "After CMS signs it, add the version's key to public_certificate / public_private_key",
      "(and public_certificate_chain if provided) via SOPS, then re-apply.",
      "---",
    ]
  ])) : null
}

output "public_cert_arns" {
  description = "Map of version to ACM certificate ARN, for every version currently imported into ACM. Use the entry matching your target version when wiring up a listener."
  value       = { for k, c in aws_acm_certificate.public : k => c.arn }
  sensitive   = true
}

output "public_cert_latest_version" {
  description = "The highest version number currently declared in public_certificate_versions. Not necessarily imported yet — check public_cert_arns for that."
  value       = local._latest_cert_version
}

output "public_cert_pending_versions" {
  description = "Versions with a CSR generated but no signed certificate material supplied yet."
  value       = local._pending_versions
}

output "csr_retrieval_instructions" {
  description = "Instructions for retrieving the latest CSR and submitting to CMS."
  value       = local.csr_instructions
}

