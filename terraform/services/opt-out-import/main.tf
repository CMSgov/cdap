locals {
  full_name = "${var.app_team}-${var.app_env}-opt-out-import"
}

resource "aws_kms_key" "queue" {
  description         = "For ${local.full_name} lambda queue"
  enable_key_rotation = true
}

resource "aws_kms_alias" "queue" {
  name          = "alias/${local.full_name}-lambda"
  target_key_id = aws_kms_key.queue.key_id
}

resource "aws_sqs_queue" "file_updates" {
  name              = "${local.full_name}-lambda"
  kms_master_key_id = aws_kms_alias.queue.name
}

data "aws_iam_policy_document" "allow_sns" {
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

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.file_updates.id
  policy    = data.aws_iam_policy_document.allow_sns.json
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
