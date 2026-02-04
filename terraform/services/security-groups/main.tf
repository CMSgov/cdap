module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=408fbd0c53b85d09a71d5c573de779bde5ae08e6"
  providers   = { aws = aws, aws.secondary = aws.secondary }
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/security-groups"
  service     = "security-groups"
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
