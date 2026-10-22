resource "aws_security_group" "codebuild_project" {
  for_each = toset(local.repos)

  name = "${each.key}-${module.standards.account_env_suffix}-codebuild-project"

  description = "For the ${module.standards.account_env_suffix} ${each.key}"
  vpc_id      = module.standards.cdap_vpc.id
}

# FIXME Evaluate how this can be limited, requires retrieval of all build dependencies. 
# FIXME Evaluate how this can be limited, requires multi-region use of IAM (IP based egress for secondary provider though primary provider is using interface endpoint)
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
  name   = "cdap-east-${module.standards.env}-vpce-endpoints"
  vpc_id = module.standards.cdap_vpc.id
}

data "aws_security_group" "endpoint_clients" {
  name   = "cdap-east-${module.standards.env}-vpce-clients"
  vpc_id = module.standards.cdap_vpc.id
}

data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${module.standards.primary_region.name}.s3"
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  for_each = aws_security_group.codebuild_project

  security_group_id = aws_security_group.codebuild_project[each.key].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 via gateway endpoint"
}

