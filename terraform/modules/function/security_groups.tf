resource "aws_security_group" "function" {
  name        = "${local.full_name_string}-function"
  description = "For the ${local.full_name_string} function"
  vpc_id      = var.platform.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "default" {
  security_group_id = aws_security_group.function.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Allow HTTPS for external calls."
}

# -------------------------------------------------------
# Use VPC Gateway and Interface Endpoints
# -------------------------------------------------------

data "aws_security_group" "vpce_clients_all" {
  name   = "${var.platform.vpc_name}-vpce-clients-all"
  vpc_id = var.platform.vpc_id
}

