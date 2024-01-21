locals {
  full_name = "${var.app}-${var.env}-opt-out-import"
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

module "opt_out_import_lambda" {
  source = "../../modules/lambda"

  app = var.app
  env = var.env

  function_name        = local.full_name
  function_description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  lambda_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-import"
  }
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
