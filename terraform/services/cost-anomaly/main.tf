data "aws_caller_identity" "current" {}
locals {
  function_name = "cost-anomaly-alert"
}
resource "aws_ce_anomaly_monitor" "BCDA_Account_Monitor" {
  name              = "BCDA Account Monitor"
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
    aws_ce_anomaly_monitor.BCDA_Account_Monitor.arn
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
        values        = ["100"]
      }
    }
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["20"]
      }
    }
  }
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name          = "cost-anomaly-alert-queue"
  sns_topic_arn = aws_sns_topic.cost_anomaly_sns.arn

  app           = "bcda"
  env           = var.env
  function_name = local.function_name

  depends_on = ["module.cost_anomaly_function"]
}

module "cost_anomaly_function" {
  source = "../../modules/function"

  app = "bcda"
  env = var.env

  name        = local.function_name
  description = "Forwards cost anomaly alerts to Slack channel #dasg-metrics-and-insights."

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  memory_size = 2048

  environment_variables = {
    ENV      = var.env
    IGNORE_OK = true
  }
}
