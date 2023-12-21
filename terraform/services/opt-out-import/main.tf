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

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [var.bfd_bucket_role_arn]
  }
}

resource "aws_iam_policy" "assume_bucket_role" {
  name = "${local.full_name}-assume-bucket-role"

  description = "Allows the ${local.full_name} lambda role to assume the bucket role in the BFD account"

  policy = data.aws_iam_policy_document.assume_bucket_role.json
}

module "opt_out_import_lambda" {
  source = "../../modules/lambda"

  function_name        = local.full_name
  function_description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.lambda_handler
  runtime = var.lambda_runtime

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.subnets.subnet_ids

  lambda_role_managed_policy_arns = [aws_iam_policy.assume_bucket_role.arn]

  environment_variables = {
    ENV      = var.app_env
    APP_NAME = "${var.app_team}-${var.app_env}-opt-out-import"
  }
}

module "opt_out_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.opt_out_import_lambda.function_name
  sns_topic_arn = var.bfd_sns_topic_arn
}
