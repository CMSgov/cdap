locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"
}

import {
  to = module.sns_to_slack_function.aws_cloudwatch_log_group.function
  id = "/aws/lambda/${local.full_name}"
}

data "aws_ssm_parameters_by_path" "slack_webhook_urls" {
  for_each = toset(var.apps_served)
  path     = "/${each.value}/lambda/slack_webhook_url"
}

module "sns_to_slack_function" {
  source = "../../modules/function"

  app          = var.app
  env          = var.env
  architecture = "arm64"

  name        = local.full_name
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  ssm_parameter_paths = flatten([
    for app, data in data.aws_ssm_parameters_by_path.slack_webhook_urls :
    data.arns
  ])

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

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
  }
}

module "sns_to_slack_queue" {
  source = "github.com/CMSgov/cdap/terraform/modules/queue?ref=b177921621c97d02dc4a21f830e4532147aa0749"

  app           = var.app
  env           = var.env
  name          = local.full_name
  function_name = module.sns_to_slack_function.name

  policy_documents = [
    data.aws_iam_policy_document.sqs_queue_policy.json
  ]
}

data "aws_iam_policy_document" "sqs_queue_policy" {
  statement {
    sid    = "allow_sns_access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "SQS:SendMessage",
    ]

    resources = [
      module.sns_to_slack_queue.arn
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:sns:us-east-1:${module.standards.account_id}:*"
      ]
    }
  }
}
