locals {
  stdenv = (
    var.app == "bcda" ? (var.env == "sbx" ? "opensbx" : var.env) :
    var.app == "dpc" ? (var.env == "sbx" ? "prod-sbx" : var.env) :
    var.env
  )
}

data "aws_ssm_parameter" "cdap_mgmt_vpc_cidr" {
  count = var.legacy ? 0 : 1

  name = "/cdap/mgmt-vpc/cidr"
}

module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
  legacy = var.legacy
}

resource "aws_security_group" "zscaler_public" {
  name        = "${var.app}-${var.env}-allow-zscaler-public"
  description = "Allow public zscaler traffic"
  vpc_id      = module.vpc.id
  tags = {
    Name = "${var.app}-${var.env}-allow-zscaler-public"
  }
}

resource "aws_security_group" "zscaler_private" {
  name        = "${var.app}-${var.env}-allow-zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
  tags = {
    Name = "${var.app}-${var.env}-allow-zscaler-private"
  }
}

resource "aws_security_group" "internet" {
  name        = "${var.app}-${var.env}-internet"
  description = "Allow access to the internet"
  vpc_id      = module.vpc.id
  tags = {
    Name = "${var.app}-${var.env}-internet"
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
  count       = var.legacy ? 0 : 1
  name        = "${var.app}-${local.stdenv}-remote-management"
  description = "Security group for remote management"
  vpc_id      = module.vpc.id
  tags = {
    Name = "${var.app}-${local.stdenv}-remote-management"
  }
}

resource "aws_vpc_security_group_ingress_rule" "remote_management_allow_all" {
  count             = var.legacy ? 0 : 1
  security_group_id = aws_security_group.remote_management[0].id
  description       = "Allow all traffic to CDAP management VPC"
  cidr_ipv4         = !var.legacy ? data.aws_ssm_parameter.cdap_mgmt_vpc_cidr[0].value : null
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "remote_management_egress" {
  count             = var.legacy ? 0 : 1
  security_group_id = aws_security_group.remote_management[0].id

  description = "Allow all egress"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_security_group" "enterprise_tools" {
  count       = var.legacy ? 0 : 1
  name        = "${var.app}-${local.stdenv}-enterprise-tools"
  description = "Security group for enterprise tools"
  vpc_id      = module.vpc.id
  tags = {
    Name = "${var.app}-${local.stdenv}-enterprise-tools"
  }
}

resource "aws_vpc_security_group_ingress_rule" "enterprise_tools_allow_all" {
  count             = var.legacy ? 0 : 1
  security_group_id = aws_security_group.enterprise_tools[0].id
  description       = "Allow all traffic to CDAP management VPC"
  cidr_ipv4         = !var.legacy ? data.aws_ssm_parameter.cdap_mgmt_vpc_cidr[0].value : null
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "enterprise_tools_egress" {
  count             = var.legacy ? 0 : 1
  security_group_id = aws_security_group.enterprise_tools[0].id

  description = "Allow all egress"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}
