locals {
  full_name = "${var.app}-${var.env}-opt-out-import"
}

module "vpc" {
  source = "../../modules/vpc"

  app = var.app
  env = var.env
}

module "subnets" {
  source = "../../modules/subnets"

  vpc_id = module.vpc.vpc_id
  app    = var.app
  layer  = "data"
}

data "aws_ssm_parameter" "bfd_bucket_role_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-bucket-role-arn"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [data.aws_ssm_parameter.bfd_bucket_role_arn.value]
  }
}

# Prod and sbx deploy roles are only needed in the test environment
data "aws_ssm_parameter" "prod_deploy_role_arn" {
  count = var.env == "test" ? 1 : 0
  name  = "/${var.app}/prod/deploy-role-arn"
}

data "aws_ssm_parameter" "sbx_deploy_role_arn" {
  count = var.env == "test" ? 1 : 0
  name  = "/${var.app}/sbx/deploy-role-arn"
}

module "opt_out_import_lambda" {
  source = "../../modules/lambda"

  function_name        = local.full_name
  function_description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.subnets.subnet_ids

  lambda_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-import"
  }

  promotion_roles = var.env != "test" ? [] : [
    data.aws_ssm_parameter.prod_deploy_role_arn[0].value,
    data.aws_ssm_parameter.sbx_deploy_role_arn[0].value,
  ]
}

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "opt_out_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.opt_out_import_lambda.function_name
  sns_topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
}
