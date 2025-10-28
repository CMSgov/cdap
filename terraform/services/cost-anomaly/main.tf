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


data "aws_iam_policy_document" "sns_send_message" {

  statement {
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

  source_policy_documents   = [data.aws_iam_policy_document.sns_send_message.json]
  override_policy_documents = var.override_policy_documents

  name = "cost-anomaly-alert-queue"

  app           = "bcda"
  env           = var.env
  function_name = local.function_name

}

resource "aws_sns_topic_subscription" "this" {
  endpoint  = module.sns_to_slack_queue
  protocol  = "sqs"
  topic_arn = aws_sns_topic.cost_anomaly_sns.arn
}
