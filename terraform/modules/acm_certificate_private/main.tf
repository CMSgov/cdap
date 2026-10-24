locals {
  domain_name = coalesce(var.domain_name, var.platform.service)

  hosted_zone_base_internal = "${var.platform.env}.${var.platform.app}.internal.cms.gov"
  hosted_zone_base_zscaler  = "${var.platform.env}.${var.platform.app}.cmscloud.local"

  internal_domain = (var.enable_internal_endpoint || var.enable_mtls_sidecar) ? (
    "${local.domain_name}.${trimsuffix(data.aws_route53_zone.internal[0].name, ".")}"
  ) : null
  zscaler_domain = var.enable_zscaler_endpoint ? "${local.domain_name}.${trimsuffix(data.aws_route53_zone.zscaler[0].name, ".")}" : null

  private_primary_domain = try(coalesce(local.internal_domain, local.zscaler_domain), null)

  private_subject_alternative_names = compact([
    (var.enable_internal_endpoint && var.enable_zscaler_endpoint) ? local.zscaler_domain : null,
  ])

  needs_private_cert = (
    var.enable_internal_endpoint ||
    var.enable_zscaler_endpoint ||
    var.enable_mtls_sidecar
  )
}

data "aws_ram_resource_share" "pace_ca" {
  count          = local.needs_private_cert ? 1 : 0
  resource_owner = "OTHER-ACCOUNTS"
  name           = var.pca_ram_resource_share_name
}

data "aws_route53_zone" "internal" {
  count        = (var.enable_internal_endpoint || var.enable_mtls_sidecar) ? 1 : 0
  name         = local.hosted_zone_base_internal
  private_zone = true
}

data "aws_route53_zone" "zscaler" {
  count        = var.enable_zscaler_endpoint ? 1 : 0
  name         = local.hosted_zone_base_zscaler
  private_zone = true
}

# -------------------------------------------------------
# PRIVATE: Issue from AWS Private CA
# -------------------------------------------------------
resource "aws_acm_certificate" "private" {
  count = local.needs_private_cert ? 1 : 0

  certificate_authority_arn = one(data.aws_ram_resource_share.pace_ca[0].resource_arns)
  domain_name               = local.private_primary_domain
  subject_alternative_names = local.private_subject_alternative_names

  tags = {
    Name    = "${local.private_primary_domain}-private-cert"
    MtLS    = tostring(var.enable_mtls_sidecar)
    Zscaler = tostring(var.enable_zscaler_endpoint)
  }

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = true
  }
}
