locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"

  extra_kms_key_arns = var.app == "bcda" ? [data.aws_kms_alias.bcda_app_config_kms_key[0].target_key_arn] : []
}

data "aws_kms_alias" "bcda_app_config_kms_key" {
  count = var.app == "bcda" ? 1 : 0
  name  = "alias/bcda-${var.env}-app-config-kms"
}

module "sns_to_slack_function" {
  source = "github.com/CMSgov/cdap/terraform/modules/function?ref=e37e99cef05ea7c779e6ea188fc29b13387bd2b5"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Listens for CloudWatch Alerts and forwards to Slack"

  # TODO use zip file

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  environment_variables = {
    IGNORE_OK = true
  }
  extra_kms_key_arns = local.extra_kms_key_arns
}

module "sns_to_slack_queue" {
  source = "github.com/CMSgov/cdap/terraform/modules/queue?ref=e37e99cef05ea7c779e6ea188fc29b13387bd2b5"

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
    sid    = "user_updates_sqs_target"
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
  }
}
