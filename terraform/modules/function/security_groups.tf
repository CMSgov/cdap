resource "aws_security_group" "function" {
  name        = "${local.full_name_string}-function"
  description = "For the ${local.full_name_string} function"
  vpc_id      = module.vpc.id
}

# -------------------------------------------------------
# Use VPC Gateway and Interface Endpoints
# -------------------------------------------------------
data "aws_security_group" "endpoints" {
  name   = "${module.platform.primary_vpc_name}-vpce-endpoints"
  vpc_id = module.platform.vpc_id
}

data "aws_security_group" "endpoint_clients" {
  name   = "${module.platform.primary_vpc_name}-vpce-clients"
  vpc_id = module.platform.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.function.id
  referenced_security_group_id = data.aws_security_group.endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Interface endpoints (SSM, KMS, Secrets Manager, logs, STS, ECR, SQS, SNS)"
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
