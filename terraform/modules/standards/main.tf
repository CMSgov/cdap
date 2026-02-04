locals {
  app           = var.app
  env           = var.env
  root_module   = var.root_module
  service       = var.service
  account_env   = contains(["sandbox", "prod"], local.env) ? "prod" : "non-prod"
  region_dir    = regex("east|west", data.aws_region.current.name)
  cdap_vpc_name = "cdap-${local.region_dir}-${local.account_env == "prod" ? "prod" : "test"}"

  static_tags = {
    application    = local.app
    business       = "oeda"
    environment    = local.env
    service        = local.service
    terraform      = true
    tf_root_module = local.root_module
  }
}

data "aws_region" "this" {}
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "aws_region" "current" {}

data "aws_caller_identity" "this" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}


data "aws_vpc" "cdap_vpc" {
  filter {
    name   = "tag:Name"
    values = [local.cdap_vpc_name]
  }
}
