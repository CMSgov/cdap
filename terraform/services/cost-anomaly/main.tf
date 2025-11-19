locals {
  function_name = "cost-anomaly-alert"
  app           = "bcda"
  service       = "cost-anomaly"
  default_tags  = module.platform.default_tags
  ssm_parameter = "/cdap/sensitive/webhook/cost-anomaly"
}

module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=plt-1358_sops"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = local.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/terraform/services/cost-anomaly"
  service     = local.service
}

resource "aws_ce_anomaly_monitor" "account_alerts" {
  name              = "AccountAlerts"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_sns_topic" "cost_anomaly_sns" {
  name              = "cost-anomaly-topic"
  kms_master_key_id = "alias/bcda-${var.env}"
}

resource "aws_ce_anomaly_subscription" "realtime_subscription" {
  name      = "cost_anomaly_subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.account_alerts.arn
  ]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_anomaly_sns.arn
  }

  threshold_expression {
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["20"]
      }
    }
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["5"]
      }
    }
  }
}

data "aws_iam_policy_document" "sns_send_message" {

  statement {
    sid     = "SnsSendMessage"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [module.sns_to_slack_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.cost_anomaly_sns.arn]
    }
  }
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = "cost-anomaly-alert-queue"

  app              = "bcda"
  env              = var.env
  function_name    = local.function_name
  policy_documents = [data.aws_iam_policy_document.sns_send_message.json]
}

resource "aws_sns_topic_subscription" "this" {
  endpoint  = module.sns_to_slack_queue.arn
  protocol  = "sqs"
  topic_arn = aws_sns_topic.cost_anomaly_sns.arn
}

# IAM role for Lambda execution
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cost_anomaly_alert" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Package the Lambda function code
data "archive_file" "cost_anomaly_alert" {
  type        = "zip"
  source_file = "lambda_src/lambda_function.py"
  output_path = "lambda/cost_anomaly_function.zip"
}

# Lambda function
resource "aws_lambda_function" "cost_anomaly_alert" {
  filename         = data.archive_file.cost_anomaly_alert.output_path
  function_name    = "cost_anomaly_alert_lambda_function"
  role             = aws_iam_role.cost_anomaly_alert.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.cost_anomaly_alert.output_base64sha256

  runtime = "python3.13"

  environment {
    variables = {
      ENVIRONMENT   = var.env
      IGNORE_OK     = "false"
      WEBHOOK_PARAM = local.ssm_parameter
    }
  }

  tags = {
    Environment = var.env
    Application = "cost_anomaly_alert"
  }
}
