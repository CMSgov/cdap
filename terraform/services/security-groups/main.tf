module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=85036477992f8ce7e574cbdfcfd5f4c549dfc92d"
  providers   = { aws = aws, aws.secondary = aws.secondary }
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/security-groups"
  service     = "security-groups"
}

# Codebuild access to application VPC
data "aws_security_groups" "codebuild_runners" {
  filter {
    name   = "group-name"
    # include all codebuild projects for repos with var.app in the name
    values = ["${var.app}*-${module.standards.account_env_suffix}-codebuild-project"]
  }

  filter {
    name   = "vpc-id"
    values = [module.standards.cdap_vpc.id]
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_codebuild_runners" {
  for_each = toset(data.aws_security_groups.codebuild_runners.ids)

  security_group_id            = aws_security_group.remote_management.id
  description                  = "Allow traffic from CodeBuild runner SG"
  referenced_security_group_id = each.value
  ip_protocol                  = "-1"
}

resource "aws_security_group" "remote_management" {
  name        = "remote-management"
  description = "Allow access from remote management VPC"
  vpc_id      = module.vpc.id
  tags = {
    Name = "remote-management"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
}

data "aws_ssm_parameter" "zscaler_public_ips" {
  name            = "/cdap/sensitive/zscaler/public-ips"
  with_decryption = true
}

data "aws_ssm_parameter" "zscaler_private_ips" {
  name            = "/cdap/sensitive/zscaler/private-ips"
  with_decryption = true
}

locals {
  zscaler_public_cidrs  = [for ip in split(",", data.aws_ssm_parameter.zscaler_public_ips.value) : trimspace(ip)]
  zscaler_private_cidrs = [for ip in split(",", data.aws_ssm_parameter.zscaler_private_ips.value) : trimspace(ip)]
}

resource "aws_vpc_security_group_ingress_rule" "zscaler_public" {
  for_each = toset(local.zscaler_public_cidrs)

  security_group_id = aws_security_group.zscaler_public.id
  description       = "Zscaler public IP"
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "zscaler_private" {
  for_each = toset(local.zscaler_private_cidrs)

  security_group_id = aws_security_group.zscaler_private.id
  description       = "Zscaler private IP"
  cidr_ipv4         = each.value
  ip_protocol       = "-1"
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

# When we introduce the network firewall, we can remove this in favor of always 443
resource "aws_vpc_security_group_egress_rule" "internet_http" {
  security_group_id = aws_security_group.internet.id

  description = "Allow http access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

# When we introduce the network firewall, we can also scope this down
resource "aws_vpc_security_group_egress_rule" "internet_https" {
  security_group_id = aws_security_group.internet.id

  description = "Allow https access to the internet"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}
