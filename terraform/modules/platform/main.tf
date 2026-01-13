locals {
  app              = var.app
  env              = var.env
  established_envs = ["test", "dev", "sandbox", "prod"]
  root_module      = var.root_module
  parent_env       = one([for x in local.established_envs : x if can(regex("${x}$$", local.env))])
  sdlc_env         = contains(["sandbox", "prod"], local.parent_env) ? "production" : "non-production"
  service          = var.service

  static_tags = {
    application    = local.app
    business       = "oeda"
    environment    = local.env
    parent_env     = local.parent_env
    service        = local.service
    terraform      = true
    tf_root_module = local.root_module
  }

  access_logs_bucket = {
    "dev"     = "bucket-access-logs-20250409172631068600000001"
    "test"    = "bucket-access-logs-20250409172631068600000001"
    "sandbox" = "bucket-access-logs-20250411172631068600000001"
    "prod"    = "bucket-access-logs-20250411172631068600000001"
  }

  aws_iam_role_names = [
    "ct-ado-bcda-application-admin",
    "ct-ado-dasg-application-admin"
  ]

  aws_security_group_names = [
    "cmscloud-security-tools",
    "internet",
    "remote-management",
    "zscaler-private",
    "zscaler-public",
  ]
}

data "aws_ssm_parameters_by_path" "ssm" {
  for_each = var.ssm_root_map

  recursive       = true
  path            = each.value
  with_decryption = true
}

data "aws_region" "primary" {}
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["${local.app}-east-${local.parent_env}"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:use"
    values = ["private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:use"
    values = ["public"]
  }
}

data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.key
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.key
}

data "aws_nat_gateways" "this" {
  vpc_id = data.aws_vpc.this.id

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_nat_gateway" "this" {
  for_each = toset(data.aws_nat_gateways.this.ids)
  id       = each.key
}

data "aws_s3_bucket" "access_logs" {
  bucket = local.access_logs_bucket[local.parent_env]
}

data "aws_s3_bucket" "logs_to_splunk" {
  bucket = "cms-cloud-${data.aws_caller_identity.this.account_id}-${data.aws_region.primary.name}"
}

data "aws_security_groups" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:Name"
    values = local.aws_security_group_names
  }
}

data "aws_security_group" "this" {
  for_each = toset(local.aws_security_group_names)
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  name = each.key
}

data "aws_ssm_parameter" "platform_cidr" {
  name            = "/cdap/sensitive/mgmt-vpc/cidr"
  with_decryption = true
}

data "aws_iam_role" "this" {
  for_each = toset(local.aws_iam_role_names)
  name     = each.key
}

data "aws_kms_alias" "primary" {
  name = "alias/${local.app}-${local.parent_env}"
}

data "aws_kms_alias" "secondary" {
  provider = aws.secondary

  name = "alias/${local.app}-${local.parent_env}"
}
