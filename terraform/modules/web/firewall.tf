resource "aws_ssm_parameter" "allowed_ip_list" {
  name  = var.ssm_parameter
  value = lookup(lookup(var.platform.ssm, "${var.service}", "static_site"), "waf_ip_allow_list", [])
  type  = "List"
}

# WAF and firewall
resource "aws_wafv2_ip_set" "this" {
  # There is no IP blocking in Prod for the Static Site
  count              = length(module.aws_ssm_parameter.allowed_ip_list.value) < 1 ? 0 : 1
  name               = "${local.naming_prefix}-${var.service}"
  description        = "IP set with access to ${var.domain_name}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = sensitive(module.aws_ssm_parameter.allowed_ip_list.value)
}

module "firewall" {
  source       = "../firewall"
  name         = local.naming_prefix
  app          = var.platform.app
  env          = var.platform.env
  scope        = "CLOUDFRONT"
  content_type = "APPLICATION_JSON"
  ip_sets      = concat(one(aws_wafv2_ip_set.this[*].arn), var.additional_allowed_ip_list)
}
