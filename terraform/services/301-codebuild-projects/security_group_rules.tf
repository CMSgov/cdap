# FIXME Evaluate how this can be limited, requires retrieval of all build dependencies 
resource "aws_vpc_security_group_egress_rule" "codebuild_project" {
  for_each = aws_security_group.codebuild_project

  security_group_id = aws_security_group.codebuild_project[each.key].id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
  from_port   = -1
  to_port     = -1
}

# -------------------------------------------------------
# Use VPC Gateway and Interface Endpoints
# -------------------------------------------------------
data "aws_security_group" "endpoints" {
  name   = "${var.platform.vpc_name}-vpce-endpoints"
  vpc_id = var.platform.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.task[0].id
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
  security_group_id = aws_security_group.task[0].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 via gateway endpoint"
}

