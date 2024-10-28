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
  # agg_table    = "agg_metrics"
  api_profile = "${local.stack_prefix}-api"
  # api_table    = "api_metrics"
}

data "aws_s3_bucket" "dpc-insights-bucket" {
  bucket = "/${local.stack_prefix}-${local.account_id}"
}
