locals {
  app             = var.app
  env             = var.env
  root_module     = var.root_module
  service         = var.service
  cdap_vpc_env    = contains(["sandbox", "prod"], local.env) ? "prod" : "test"
  cdap_vpc_region = replace(trimprefix(data.aws_region.current.name, "us-"), "/-[0-9]+$/", "")
  cdap_vpc_name   = "cdap-${cdap_vpc_env}-${cdap_vpc_region}"

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
trimmed_string = trimsuffix(trimprefix(local.original_string, "us-"), "-1")
data "aws_caller_identity" "this" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

locals {
}

data "aws_vpc" "mgmt_vpc" {
  filter {
    name   = "tag:Name"
    values = [local.cdap_vpc_name]
  }
}