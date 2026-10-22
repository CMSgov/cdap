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
data "aws_security_group" "endpoints" {
  name   = "${var.platform.vpc_name}-vpce-endpoints"
  vpc_id = var.platform.vpc_id
}

data "aws_security_group" "endpoint_clients" {
  name   = "${var.platform.vpc_name}-vpce-clients"
  vpc_id = var.platform.vpc_id
}

data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${var.platform.primary_region.name}.s3"
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  count             = var.needs_s3_access ? 1 : 0
  security_group_id = aws_security_group.function.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 via gateway endpoint"
}
