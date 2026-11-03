locals {
  base_name                 = "${var.platform.app}-${var.platform.env}-${var.platform.service}"
  subnet_ids                = [for s in var.platform.private_subnets : s.id]
  hosted_zone_base_internal = "${var.platform.env}.${var.platform.app}.internal.cms.gov"
}

data "aws_ssm_parameter" "service_name" {
  count = var.ssm_parameter_name != null ? 1 : 0
  name  = var.ssm_parameter_name
}

locals {
  resolved_service_name = coalesce(var.service_name, try(data.aws_ssm_parameter.service_name[0].value, null))
}

resource "aws_security_group" "this" {
  name        = "${local.base_name}-vpce-sg"
  description = "Security group for the PrivateLink interface endpoint"
  vpc_id      = var.platform.vpc_id

  tags = { Name = "${local.base_name}-vpce-sg" }
}

resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.platform.vpc_id
  service_name        = local.resolved_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.this.id]
  private_dns_enabled = false # keep false so AWS does not manage as it requires public domain based validation of TXT records

  tags = { Name = "${local.base_name}-vpce" }
}

# Friendly name, in a zone this account/VPC owns. Interface endpoint DNS
# names aren't eligible for alias records, so this is a plain CNAME.

data "aws_route53_zone" "internal" {
  count        = var.dns_record_name != null ? 1 : 0
  name         = local.hosted_zone_base_internal
  private_zone = true
}

resource "aws_route53_record" "friendly_name" {
  count = var.dns_record_name != null ? 1 : 0

  zone_id = data.aws_route53_zone.internal[0].zone_id
  name    = var.dns_record_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_vpc_endpoint.this.dns_entry[0].dns_name]
}
