locals {
  internal_domain = var.enable_internal_endpoint ? "${var.platform.service}.${trimsuffix(data.aws_route53_zone.internal[0].name, ".")}" : null
  zscaler_domain  = var.enable_zscaler_endpoint ? "${var.platform.service}.${trimsuffix(data.aws_route53_zone.zscaler[0].name, ".")}" : null

  private_primary_domain = (
    var.enable_internal_endpoint ? local.internal_domain :
    var.enable_zscaler_endpoint ? local.zscaler_domain :
    null
  )

  private_subject_alternative_names = (
    var.enable_internal_endpoint && var.enable_zscaler_endpoint
  ) ? [local.zscaler_domain] : []
}

# -------------------------------------------------------
# PRIVATE: Issue from AWS Private CA
# -------------------------------------------------------
resource "aws_acm_certificate" "private" {
  count = (var.enable_internal_endpoint || var.enable_zscaler_endpoint) ? 1 : 0

  certificate_authority_arn = one(data.aws_ram_resource_share.pace_ca[0].resource_arns)
  domain_name               = local.private_primary_domain
  subject_alternative_names = local.private_subject_alternative_names

  tags = { Name = "${local.private_primary_domain}-private-cert" }

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "private" {
  count           = (var.enable_internal_endpoint || var.enable_zscaler_endpoint) ? 1 : 0
  certificate_arn = aws_acm_certificate.private[0].arn

  timeouts {
    create = "5m"
  }
}

# -------------------------------------------------------
# PUBLIC PATH: Import CMS-signed cert (developer note: use SOPS encrypted values)
# -------------------------------------------------------

resource "tls_private_key" "this" {
  for_each  = var.public_domain_name != null ? toset([for v in var.public_certificate_versions : tostring(v)]) : toset([])
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "this" {
  for_each        = var.public_domain_name != null ? toset([for v in var.public_certificate_versions : tostring(v)]) : toset([])
  private_key_pem = tls_private_key.this[each.key].private_key_pem

  subject {
    country             = "US"
    province            = "MD"
    locality            = "Rockville"
    organization        = "US Dept of Health and Human Services"
    organizational_unit = "Centers for Medicare and Medicaid Services"
    common_name         = var.public_domain_name
  }
}

# -------------------------------------------------------
# Store private key in SSM — encrypted with platform KMS key
# -------------------------------------------------------

resource "aws_ssm_parameter" "private_key" {
  for_each = var.public_domain_name != null ? toset([for v in var.public_certificate_versions : tostring(v)]) : toset([])

  name   = "/${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${each.key}/private-key"
  type   = "SecureString"
  value  = tls_private_key.this[each.key].private_key_pem
  key_id = var.platform.kms_alias_primary.target_key_arn

  tags = { Name = "${var.public_domain_name}-private-key" }

  lifecycle {
    # Prevent Terraform from overwriting the key if it already exists.
    # The private key must remain stable — replacing it may invalidate signed certs.
    ignore_changes = [value]
  }
}

# -------------------------------------------------------
# Store CSR in SSM — plaintext is fine, CSRs are not sensitive
# Developers can retrieve this value and submit it to CMS for signing.
# -------------------------------------------------------

resource "aws_ssm_parameter" "csr" {
  for_each = var.public_domain_name != null ? toset([for v in var.public_certificate_versions : tostring(v)]) : toset([])

  name        = "/${var.platform.app}/${var.platform.env}/${var.platform.service}/tls/v${each.key}/csr"
  description = "Certificate Signing Request for ${var.public_domain_name}. Submit this to CMS for signing."
  type        = "String"
  value       = tls_cert_request.this[each.key].cert_request_pem

  lifecycle {
    ignore_changes = [value]
  }
}


# Once cert information is provided via SOPS path, this will be set
resource "aws_acm_certificate" "public" {
  count = (
    var.public_domain_name != null &&
    var.public_certificate != null &&
    var.public_private_key != null
  ) ? 1 : 0

  certificate_body  = var.public_certificate
  private_key       = var.public_private_key
  certificate_chain = var.public_certificate_chain

  tags = { Name = var.public_domain_name }

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}
