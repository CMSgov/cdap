locals {
  full_name = "${var.app_team}-${var.app_env}-opt-out-import"
}

module "vpc" {
  source = "../../modules/vpc"

  app_team = var.app_team
  app_env  = var.app_env
}

module "subnets" {
  source = "../../modules/subnets"

  vpc_id   = module.vpc.vpc_id
  app_team = var.app_team
  layer    = "data"
}

module "opt_out_import_lambda" {
  source = "../../modules/lambda"

  function_name        = local.full_name
  function_description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.lambda_handler
  runtime = var.lambda_runtime

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.subnets.subnet_ids

  environment_variables = {
    ENV                 = var.app_env
    APP_NAME            = "${var.app_team}-${var.app_env}-opt-out-import"
    AWS_ASSUME_ROLE_ARN = var.bfd_bucket_role
  }
}
