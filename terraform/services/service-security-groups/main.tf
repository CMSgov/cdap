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
}

resource "aws_security_group" "zscaler_private" {
  name        = "${var.app}-${var.env}-allow-zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
}

resource "aws_security_group" "internet" {
  name        = "${var.app}-${var.env}-internet"
  description = "Allow access to the internet"
  vpc_id      = module.vpc.id
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
