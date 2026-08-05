# Public ALB internet ingress
resource "aws_vpc_security_group_ingress_rule" "https_public" {
  count             = (local.managed_sg && !var.internal) ? 1 : 0
  security_group_id = aws_security_group.alb[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS from internet. WAF blocks at Level 7"
}

# HTTP ingress — only when http_redirect is enabled
resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = (local.managed_sg && var.enable_http_redirect) ? 1 : 0
  security_group_id = aws_security_group.alb[0].id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.internal ? var.platform.vpc_cidr : "0.0.0.0/0"
  description       = var.internal ? "Allow HTTP from VPC (redirect to HTTPS)" : "Allow HTTP from internet (redirect to HTTPS)"
}

# Zscaler private App Connector ingress
# Use for internal ALBs registered in cmscloud.local DNS
resource "aws_vpc_security_group_ingress_rule" "https_zscaler" {
  count                        = (local.managed_sg && var.enable_zscaler_ingress) ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = var.platform.security_groups["zscaler-private"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from Zscaler private App Connector"
}

# Datadog synthetics private location ingress
resource "aws_vpc_security_group_ingress_rule" "https_datadog" {
  count                        = (local.managed_sg && var.enable_datadog_synthetics_ingress) ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = var.platform.security_groups["datadog-synthetics"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from Datadog synthetics private location runner"
}


# CMS security tools ingress — always on when module manages the SG
resource "aws_vpc_security_group_ingress_rule" "https_security_tools" {
  count                        = local.managed_sg ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = var.platform.security_groups["cmscloud-security-tools"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from CMS security scanning tools"
}
