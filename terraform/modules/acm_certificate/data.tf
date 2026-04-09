locals {
  hosted_zone_base_internal = "${var.platform.app}-${var.platform.env}.cmscloud.internal"
  hosted_zone_base_zscaler  = "${var.platform.app}-${var.platform.env}.cmscloud.local"
}

data "aws_ram_resource_share" "pace_ca" {
  count          = (var.enable_internal_endpoint || var.enable_zscaler_endpoint) ? 1 : 0
  resource_owner = "OTHER-ACCOUNTS"
  name           = var.pca_ram_resource_share_name
}

data "aws_route53_zone" "internal" {
  count        = var.enable_internal_endpoint ? 1 : 0
  name         = local.hosted_zone_base_internal
  private_zone = true
}

data "aws_route53_zone" "zscaler" {
  count        = var.enable_zscaler_endpoint ? 1 : 0
  name         = local.hosted_zone_base_zscaler
  private_zone = true
}
