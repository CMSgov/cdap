locals {
  ab2d_env_lbs = {
    dev  = "ab2d-dev"
    test = "ab2d-east-impl"
    sbx  = "ab2d-sbx-sandbox"
    prod = "api-ab2d-east-prod"
  }
  load_balancers = {
    ab2d = "${local.ab2d_env_lbs[var.env]}"
    bcda = "bcda-api-${var.env == "sbx" ? "opensbx" : var.env}-01"
    dpc  = "dpc-${var.env == "sbx" ? "prod-sbx" : var.env}-1"
  }
  stack_prefix = "${var.app}-${local.this_env}"
  this_env     = var.env == "sbx" ? "prod-sbx" : var.env
  account_id   = data.aws_caller_identity.current.account_id
  agg_profile  = "${local.stack_prefix}-aggregator"
  api_profile  = "${local.stack_prefix}-api"

  athena_profile = "${var.app}_${local.this_env}_insights_${local.account_id}"
  athena_prefix  = "${var.app}-${local.this_env}-insights"

  dpc_glue_s3_name    = "${local.stack_prefix}-${local.account_id}"
  dpc_logging_s3_name = "${local.stack_prefix}-logs-${local.account_id}"
  dpc_athena_s3_name  = local.athena_prefix

  dpc_glue_bucket_arn         = module.dpc_insights_data.arn
  dpc_glue_bucket_key_alias   = module.dpc_insights_data.key_alias
  dpc_glue_bucket_key_arn     = module.dpc_insights_data.key_arn
  dpc_glue_bucket_key_id      = mmodule.dpc_insights_data.id
  dpc_athena_bucket_arn       = module.dpc_insights_athena.arn
  dpc_athena_bucket_key_alias = module.dpc_insights_athena.key_alias
  dpc_athena_bucket_key_arn   = module.dpc_insights_athena.key_arn
  dpc_athena_bucket_key_id    = module.dpc_insights_data.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "dpc_insights_data" {
  source = "../../modules/bucket"
  name   = local.dpc_glue_s3_name
}

module "dpc_insights_athena" {
  source = "../../modules/bucket"
  name   = local.dpc_athena_s3_name
}