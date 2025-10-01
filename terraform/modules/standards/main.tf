locals {
  app         = var.app
  env         = var.env
  root_module = var.root_module
  service     = var.service

  established_envs = ["test", "dev", "sandbox", "prod", "mgmt"]
  parent_env       = one([for x in local.established_envs : x if can(regex("${x}$$", local.env))])

  static_tags = {
    application    = local.app
    business       = "oeda"
    environment    = local.env
    parent_env     = local.parent_env
    service        = local.service
    terraform      = true
    tf_root_module = local.root_module
  }
}

data "aws_region" "this" {}
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "aws_caller_identity" "this" {}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}
