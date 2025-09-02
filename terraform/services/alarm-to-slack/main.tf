locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"

  ignore_ok = true

  extra_kms_key_arns = var.app == "bcda" ? [data.aws_kms_alias.bcda_app_config_kms_key[0].target_key_arn] : []
}

data "aws_kms_alias" "bcda_app_config_kms_key" {
  count = var.app == "bcda" ? 1 : 0
  name  = "alias/bcda-${var.env}-app-config-kms"
}

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
  extra_kms_key_arns = local.extra_kms_key_arns
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  app = var.app
  env = var.env

  name = local.full_name

  function_name = module.sns_to_slack_function.name
}
