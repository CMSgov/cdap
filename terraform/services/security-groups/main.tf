module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=85036477992f8ce7e574cbdfcfd5f4c549dfc92d"
  providers   = { aws = aws, aws.secondary = aws.secondary }
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/security-groups"
  service     = "security-groups"
}

locals {
  # Map app env -> cdap env
  cdap_env = {
    dev     = "test"
    test    = "test"
    prod    = "prod"
    sbx     = "prod"
    sandbox = "prod"
    mgmt    = "prod"
  }
}

# aws_security_groups (plural) returns an empty list when no matches are found,
# unlike the singular aws_security_group which errors if the resource doesn't exist.
# This allows safe lookup when 520-datadog-private-location is not yet deployed.
data "aws_security_groups" "datadog_private_location" {
  filter {
    name   = "group-name"
    values = ["cdap-${local.cdap_env[var.env]}-datadog-private-location-task-sg"]
  }
  filter {
    name   = "vpc-id"
    values = [module.standards.cdap_vpc.id]
  }
}

resource "aws_security_group" "datadog_synthetics" {
  name        = "datadog-synthetics"
  description = "Allow ingress from Datadog private location synthetic test runner"
  vpc_id      = module.vpc.id

  tags = {
    Name = "datadog-synthetics"
  }
}

# Only create the ingress rule if the Datadog private location SG was found.
# Once 520-datadog-private-location is deployed, the next apply will automatically
# create this rule.
resource "aws_vpc_security_group_ingress_rule" "datadog_synthetics" {
  count = length(data.aws_security_groups.datadog_private_location.ids) > 0 ? 1 : 0

  security_group_id            = aws_security_group.datadog_synthetics.id
  description                  = "Allow synthetic test traffic from Datadog private location in CDAP ${local.cdap_env[var.env]} VPC"
  referenced_security_group_id = data.aws_security_groups.datadog_private_location.ids[0]
  ip_protocol                  = "-1"
}

data "aws_ssm_parameter" "cdap_mgmt_vpc_cidr" {
  name = "/cdap/sensitive/mgmt-vpc/cidr"
}

module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
}

resource "aws_security_group" "zscaler_public" {
  name        = "zscaler-public"
  description = "Allow public zscaler traffic"
  vpc_id      = module.vpc.id
  tags = {
    Name = "zscaler-public"
  }
}

resource "aws_security_group" "zscaler_private" {
  name        = "zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
  tags = {
    Name = "zscaler-private"
  }
}

resource "aws_security_group" "internet" {
  name        = "internet"
  description = "Allow access to the internet"
  vpc_id      = module.vpc.id
  tags = {
    Name = "internet"
  }
}

resource "aws_vpc_security_group_egress_rule" "internet_http" {
  security_group_id = aws_security_group.internet.id

  description = "Allow http access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "internet_https" {
  security_group_id = aws_security_group.internet.id

  description = "Allow https access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_security_group" "remote_management" {
  name        = "remote-management"
  description = "Allow access from remote management VPC"
  vpc_id      = module.vpc.id
  tags = {
    Name = "remote-management"
  }
}

resource "aws_vpc_security_group_ingress_rule" "remote_management_allow_all" {
  security_group_id = aws_security_group.remote_management.id

  description = "Allow all traffic from CDAP management VPC"
  cidr_ipv4   = data.aws_ssm_parameter.cdap_mgmt_vpc_cidr.value
  ip_protocol = -1
}

resource "aws_vpc_security_group_ingress_rule" "allow_cdap_vpc" {
  security_group_id = aws_security_group.remote_management.id

  description = "Allow all traffic from ${module.standards.cdap_vpc.id} VPC"
  cidr_ipv4   = module.standards.cdap_vpc.cidr_block
  ip_protocol = -1
}
