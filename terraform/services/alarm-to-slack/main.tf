locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"
}

import {
  to = module.sns_to_slack_function.aws_cloudwatch_log_group.function
  id = "/aws/lambda/${local.full_name}"
}

data "aws_ssm_parameters_by_path" "slack_webhook_urls" {
  for_each = toset(var.apps_served)
  path     = "/${each.value}/${var.env}/lambda/slack_webhook_url"
}

module "sns_to_slack_function" {
  source   = "../../modules/function"
  platform = module.platform

  name        = "alarm-to-slack"
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  architecture = "arm64"
  handler      = "lambda_function.lambda_handler"
  runtime      = "python3.13"

  ssm_parameter_paths = flatten([
    for app, data in data.aws_ssm_parameters_by_path.slack_webhook_urls :
    data.path
  ])

  function_role_inline_policies = {
    sqs-trigger = data.aws_iam_policy_document.sqs_trigger.json
  }

  # Point to the local source directory — module handles zip + upload
  source_dir = "${path.module}/lambda_src"

  # Optionally exclude tests and cache
  source_dir_excludes = [
    "__pycache__",
    "test_*.py",
    "*.pyc",
  ]

  environment_variables = {
    IGNORE_OK = true
    APPS      = join(",", var.apps_served)
    SSM_ENV   = var.env
  }
}

module "sns_to_slack_queue" {
  source = "github.com/CMSgov/cdap/terraform/modules/queue?ref=b177921621c97d02dc4a21f830e4532147aa0749"

  name          = local.full_name
  function_name = module.sns_to_slack_function.name
  app           = var.app
  env           = var.env

  policy_documents = [
    data.aws_iam_policy_document.sqs_queue_policy.json
  ]
}

module "platform" {
  providers = { aws = aws, aws.secondary = aws.secondary }

  source      = "../../modules/platform"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}

## CDAP Specific SNS topic
resource "aws_sns_topic" "cloudwatch_alarms" {
  name              = "${module.platform.app}-${module.platform.env}-cloudwatch-alarms"
  kms_master_key_id = module.platform.kms_alias_primary.target_key_arn
}

resource "aws_sns_topic_subscription" "alarms_sqs" {
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "sqs"
  endpoint  = module.sns_to_slack_queue.arn
}

## Test cloudwatch metric alarm
resource "aws_cloudwatch_metric_alarm" "test" {
  alarm_name          = "${module.platform.app}-${module.platform.env}-test-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "TestMetric"
  namespace           = "TestNamespace"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  alarm_description  = "Test alarm — use set-alarm-state to trigger manually"
  alarm_actions      = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions         = [aws_sns_topic.cloudwatch_alarms.arn]
  treat_missing_data = "missing" # Stays INSUFFICIENT_DATA, not ALARM
}
