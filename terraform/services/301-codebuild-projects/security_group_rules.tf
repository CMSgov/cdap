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
data "aws_security_group" "vpce_all_clients" {
  name   = "${var.platform.primary_vpc_name}-vpce-all-clients"
  vpc_id = var.platform.vpc_id
}

data "aws_security_group" "vpce_platform_clients" {
  name   = "${var.platform.primary_vpc_name}-vpce-platform-clients"
  vpc_id = var.platform.vpc_id
}
