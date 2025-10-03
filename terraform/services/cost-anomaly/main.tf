data "aws_caller_identity" "current" {}

locals {
  function_name = "cost-anomaly-alert"
}

module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards"
  app         = "cdap"
  env         = var.env
  providers   = { aws = aws, aws.secondary = aws.secondary }
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/cost-anomaly"
  service     = "cost-anomaly"
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

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name          = "cost-anomaly-alert-queue"
  sns_topic_arn = aws_sns_topic.cost_anomaly_sns.arn

  app           = "bcda"
  env           = var.env
  function_name = local.function_name
}
