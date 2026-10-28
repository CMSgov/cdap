# -------------------------------------------------------
# Import CMS-signed cert (developer note: use SOPS encrypted values)
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
  for_each = var.public_domain_name != null ? {
    for v in var.public_certificate_versions : tostring(v) => v
    if lookup(var.public_certificate, tostring(v), null) != null
    && lookup(var.public_private_key, tostring(v), null) != null
  } : {}

  certificate_body  = var.public_certificate[each.key]
  private_key       = var.public_private_key[each.key]
  certificate_chain = try(var.public_certificate_chain[each.key], null)

  tags = { Name = "${var.public_domain_name}-v${each.key}" }

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}

