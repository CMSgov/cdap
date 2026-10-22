resource "aws_security_group" "function" {
  name        = "${local.full_name_string}-function"
  description = "For the ${local.full_name_string} function"
  vpc_id      = var.platform.vpc_id
}

# FIXME Remove this rule in PLT-1824
resource "aws_vpc_security_group_egress_rule" "default" {
  security_group_id = aws_security_group.function.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Allow HTTPS for SSM, CloudWatch, etc."
}

# -------------------------------------------------------
# Use VPC Gateway and Interface Endpoints
# -------------------------------------------------------

data "aws_security_group" "vpce_all_clients" {
  name   = "${var.platform.primary_vpc_name}-vpce-all-clients"
  vpc_id = var.platform.vpc_id
}

