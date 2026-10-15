resource "aws_vpc_security_group_ingress_rule" "endpoints_https_from_vpc" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS from VPC CIDR"
  cidr_ipv4         = module.platform.platform_cidr
  from_port         = 443
  to_port            = 443
  ip_protocol        = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https_from_zscaler" {
  security_group_id            = aws_security_group.endpoints.id
  description                   = "HTTPS from Zscaler private"
  referenced_security_group_id = module.platform.security_groups["zscaler-private"].id
  from_port                     = 443
  to_port                        = 443
  ip_protocol                    = "tcp"
}
