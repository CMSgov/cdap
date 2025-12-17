locals {
  sops_env = contains(["dev", "test"], var.env) ? "test" : "prod"
  dpc_services = concat(
    [
      "attribution",
      "aggregation",
      "api",
    ],
    var.env == "dev" ?
    [
      "web",
      "web-admin",
      "web-portal",
    ] : [],
    var.env == "test" ?
    [
      "web",
      "web-admin",
      "web-portal",
    ] : [],
    var.env == "sandbox" ?
    [
      "web",
      "web-admin",
    ] : [],
  )

  # TODO Replace with cdap-test and cdap-prod when those environments are set up
  account_env = contains(["dev", "test"], var.env) ? "bcda-test" : "bcda-prod"
}

# KMS keys needed for IAM policy
data "aws_kms_alias" "environment_key" {
  name = "alias/${var.app}-${var.env}"
}

#TODO Replace with cdap-prod and cdap-test when vpcs are in place
data "aws_kms_alias" "tmp_cdap_sops_environment_key" {
  name = "alias/bcda-${local.sops_env}"
}

data "aws_kms_alias" "ab2d_tfstate_bucket" {
  count = var.env == "ab2d" ? 1 : 0
  name  = "alias/ab2d-${var.env}-tfstate-bucket"
}

data "aws_kms_alias" "ab2d_ecr" {
  count = var.app == "ab2d" ? 1 : 0
  name  = "alias/ab2d-ecr"
}

data "aws_kms_alias" "bcda_app_config" {
  count = var.app == "bcda" ? 1 : 0
  name  = "alias/bcda-${var.env}-app-config-kms"
}

data "aws_kms_alias" "bcda_aco_creds" {
  count = var.app == "bcda" ? contains(["dev, test"], var.env) ? 1 : 0 : 0
  name  = "alias/bcda-aco-creds-kms"
}

data "aws_kms_alias" "bcda_insights_data_sampler" {
  count = var.app == "bcda" ? var.env == "dev" ? 1 : 0 : 0
  name  = "alias/bcda-insights-data-sampler-${var.env}-key"
}

data "aws_kms_alias" "dpc_app_config" {
  count = var.app == "dpc" ? 1 : 0
  name  = "alias/dpc-${var.env}-master-key"
}

data "aws_kms_alias" "dpc_ecr" {
  count = var.app == "dpc" ? 1 : 0
  name  = "alias/dpc-ecr"
}

data "aws_kms_alias" "dpc_cloudwatch_keys" {
  for_each = toset([for k in local.dpc_services : k if var.app == "dpc"])
  name     = "alias/dpc-${var.env}-${each.key}-cloudwatch-key"
}
