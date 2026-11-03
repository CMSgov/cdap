# Public ALB internet ingress
resource "aws_vpc_security_group_ingress_rule" "https_public" {
  count = (var.create_alb && local.managed_sg && !var.internal) ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS from internet. WAF blocks at Level 7"
}

# HTTP ingress — only when http_redirect is enabled
resource "aws_vpc_security_group_ingress_rule" "http" {
  count = (var.create_alb && local.managed_sg) ? 1 : 0

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
  count                        = (var.create_alb && local.managed_sg && var.create_zscaler_dns_record) ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = var.platform.security_groups["zscaler-private"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from Zscaler private App Connector"
}

data "aws_ssm_parameter" "datadog_private_location_sg" {
  count = (var.create_alb && var.enable_datadog_synthetics_ingress) ? 1 : 0
  name  = "/cdap/${var.platform.cdap_env}/datadog/nonsensitive/private_location_task_security_group_id"
}

# Datadog synthetics private location ingress
resource "aws_vpc_security_group_ingress_rule" "https_datadog" {
  count = (var.create_alb && local.managed_sg && var.enable_datadog_synthetics_ingress) ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from Datadog synthetics private location runner"
}

# CMS security tools ingress — always on when module manages the SG
resource "aws_vpc_security_group_ingress_rule" "https_security_tools" {
  count = (var.create_alb && local.managed_sg) ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = var.platform.security_groups["cmscloud-security-tools"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from CMS security scanning tools"
}

# Codebuild runner ingress option
data "aws_security_group" "codebuild_repo" {
  count = (var.create_alb && local.managed_sg && var.enable_ingress_from_codebuild_repo != null) ? 1 : 0
  name  = "${var.enable_ingress_from_codebuild_repo}-${var.platform.account_env_suffix}-codebuild-project"
}

resource "aws_vpc_security_group_ingress_rule" "codebuild" {
  count                        = (var.create_alb && local.managed_sg && var.enable_ingress_from_codebuild_repo != null) ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = data.aws_security_group.codebuild_repo[0].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from Codebuild runner"
}

# Traffic from PrivateLink interface endpoint ENIs lands here, those
# ENIs live in this VPC's subnets, so VPC CIDR is the correct scope.
# In "direct" mode, any future NLB integration in ecs-service will need
# its own ingress rule for whatever port(s) it listens on; this rule
# only covers the front_alb port.
resource "aws_vpc_security_group_ingress_rule" "nlb_from_vpc" {
  count             = (var.create_nlb && var.nlb_mode == "front_alb") ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  from_port         = var.privatelink_target_port
  to_port           = var.privatelink_target_port
  ip_protocol       = "tcp"
  cidr_ipv4         = var.platform.vpc_cidr
  description       = "Allow HTTPS from PrivateLink endpoint ENIs in this VPC"
}

# Enable NLB to reach the ALB (front_alb mode only)
resource "aws_vpc_security_group_ingress_rule" "https_from_nlb" {
  count = (
    var.create_alb && local.managed_sg &&
    var.create_nlb &&
    var.nlb_mode == "front_alb"
  ) ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = aws_security_group.nlb[0].id
  from_port                    = var.privatelink_target_port
  to_port                      = var.privatelink_target_port
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS from PrivateLink NLB"
}
