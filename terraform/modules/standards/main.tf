locals {
  app              = var.app
  env              = var.env
  root_module      = var.root_module
  service          = var.service

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
data "aws_caller_identity" "this" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}
