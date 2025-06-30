locals {
  full_name = "${var.app}-${var.env}-sns-to-slack"
  handler_name = {
    dpc  = "bootstrap"
  }
}

module "sns_to_slack_function" {
  source = "../../modules/function"

  app    = var.app
  env    = var.env
  legacy = false

  name        = local.full_name
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  handler = local.handler_name[var.app]
  runtime = "provided.al2"

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-sns-to-slack"
  }
}

# Set up queue for receiving messages when a cloudwatch alert is sent
data "aws_sns_topic" "cloudwatch" {
  name              = "${var.app}-${var.env}-cloudwatch-alarms"
}
  
module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.sns_to_slack_function.name
  sns_topic_arn = data.aws_sns_topic.cloudwatch.arn
}
