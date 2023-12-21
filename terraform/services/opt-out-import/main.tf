locals {
  full_name = "${var.app_team}-${var.app_env}-opt-out-import"
}

resource "aws_kms_key" "queue" {
  description         = "For ${local.full_name} queue"
  enable_key_rotation = true
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_for_queue" {
  statement {
    sid = "Enable IAM User Permissions"

    actions = ["kms:*"]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid = "Allow SNS topic to send message to encrypted SQS queue"

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_kms_key.queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.bfd_sns_topic_arn]
    }
  }
}

resource "aws_kms_key_policy" "queue" {
  key_id = aws_kms_key.queue.id
  policy = data.aws_iam_policy_document.kms_for_queue.json
}

resource "aws_kms_alias" "queue" {
  name          = "alias/${local.full_name}-queue"
  target_key_id = aws_kms_key.queue.key_id
}

resource "aws_sqs_queue" "file_updates" {
  name              = "${local.full_name}"
  kms_master_key_id = aws_kms_alias.queue.name
}

data "aws_iam_policy_document" "sns_send_message" {
  statement {
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [aws_sqs_queue.file_updates.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.bfd_sns_topic_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sns_send_message" {
  queue_url = aws_sqs_queue.file_updates.id
  policy    = data.aws_iam_policy_document.sns_send_message.json
}

resource "aws_sns_topic_subscription" "file_updates" {
  endpoint  = aws_sqs_queue.file_updates.arn
  protocol  = "sqs"
  topic_arn = var.bfd_sns_topic_arn
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

module "opt_out_import_lambda" {
  source = "../../modules/lambda"

  function_name        = local.full_name
  function_description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.lambda_handler
  runtime = var.lambda_runtime

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.subnets.subnet_ids

  environment_variables = {
    ENV                 = var.app_env
    APP_NAME            = "${var.app_team}-${var.app_env}-opt-out-import"
    AWS_ASSUME_ROLE_ARN = var.bfd_bucket_role_arn
  }
}

resource "aws_lambda_event_source_mapping" "file_updates" {
  event_source_arn = aws_sqs_queue.file_updates.arn
  function_name    = module.opt_out_import_lambda.function_name
}
