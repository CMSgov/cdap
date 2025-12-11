locals {
  full_name = "${var.app}-${var.env}-alarm-to-slack"
}

data "aws_caller_identity" "current" {}

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
        "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}
