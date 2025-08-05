locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"

  ignore_ok = {
    "dpc"  = "true"
    "ab2d" = "true"
    "bcda" = "true"
  }
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

    IGNORE_OK_APPS = join(",", keys(local.ignore_ok))
  }
}

data "aws_sns_topic" "cloudwatch_alarms" {
  for_each = toset(var.app_envs)
  name     = "${each.key}-cloudwatch-alarms"
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.sns_to_slack_function.name
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_to_queue" {
  for_each   = data.aws_sns_topic.cloudwatch_alarms
  topic_arn  = each.value.arn
  protocol   = "sqs"
  endpoint   = module.sns_to_slack_queue.arn
  depends_on = [module.sns_to_slack_queue]
}
