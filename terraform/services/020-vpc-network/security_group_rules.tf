# Ingress to Endpoints from clients 
resource "aws_vpc_security_group_ingress_rule" "endpoints_all_from_clients" {
  security_group_id            = aws_security_group.endpoints_all.id
  referenced_security_group_id = aws_security_group.vpc_all_clients.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_build_from_clients" {
  security_group_id            = aws_security_group.endpoints_build.id
  referenced_security_group_id = aws_security_group.vpc_build_clients.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_all_from_zscaler" {
  security_group_id            = aws_security_group.endpoints_all.id
  referenced_security_group_id = module.platform.security_groups["zscaler-private"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_build_from_zscaler" {
  security_group_id            = aws_security_group.endpoints_build.id
  referenced_security_group_id = module.platform.security_groups["zscaler-private"].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Egress from clients to endpoints 
resource "aws_vpc_security_group_egress_rule" "all_clients_to_endpoints" {
  security_group_id            = aws_security_group.vpc_all_clients.id
  referenced_security_group_id = aws_security_group.endpoints_all.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "build_clients_to_endpoints" {
  security_group_id            = aws_security_group.vpc_build_clients.id
  referenced_security_group_id = aws_security_group.endpoints_build.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
