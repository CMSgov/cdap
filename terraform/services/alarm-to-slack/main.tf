locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"

  ignore_ok = true
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "sns_to_slack_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  environment_variables = {

    IGNORE_OK = true
  }

  kms_key_arn = "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alias/${var.app}-${var.env}"
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.sns_to_slack_function.name
}
