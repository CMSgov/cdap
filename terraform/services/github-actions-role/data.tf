locals {
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

  # TODO Drop account_env_old when we are fully migrated to cdap-test and cdap-prod
  account_env_old = contains(["dev", "test"], var.env) ? "bcda-test" : "bcda-prod"
  account_env     = contains(["dev", "test"], var.env) ? "cdap-test" : "cdap-prod"
}

# KMS keys needed for IAM policy
data "aws_kms_alias" "environment_key" {
  name = "alias/${var.app}-${var.env}"
}

data "aws_kms_alias" "account_env_old" {
  name = "alias/${local.account_env_old}"
}

data "aws_kms_alias" "account_env" {
  name = "alias/${local.account_env}"
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
