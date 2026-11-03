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

# -------------------------------------------------------
# Friendly name — shadow zone
# -------------------------------------------------------
# target_domain_name is the target's acm_certificate_private
# "internal_domain" output, e.g. "myservice.dev.bcda.internal.cms.gov".
# That domain is the target cert's primary domain_name, and the target
# enrolls this app (var.platform.app) as a SAN of
# "<this app>.<target_domain_name>" via its own enrolled_upstream_apps.
#
# To prevent broad resolution between VPCs, we do NOT associate the target's full 
# hosted zone which is managed by CDAP. 
# this consumer VPC resolves against this zone while the target's
# VPC resolves against its own domain
resource "aws_route53_zone" "target_shadow" {
  name = var.target_domain_name

  vpc {
    vpc_id = var.platform.vpc_id
  }

  comment = "Shadow zone for PrivateLink to ${var.target_domain_name} — scoped to this VPC only, not the target's real zone."

  tags = { Name = "${local.base_name}-privatelink-shadow-zone" }
}

resource "aws_route53_record" "friendly_name" {
  zone_id = aws_route53_zone.target_shadow.zone_id
  name    = "${var.platform.app}.${var.target_domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_vpc_endpoint.this.dns_entry[0].dns_name]
}
