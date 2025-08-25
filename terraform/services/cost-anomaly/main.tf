data "aws_caller_identity" "current" {}

resource "aws_ce_anomaly_monitor" "BCDA_Account_Monitor" {
  name              = "BCDA Account Monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_sns_topic" "cost_anomaly_updates" {
  name              = "cost-anomaly-updates"
  kms_master_key_id = "alias/bcda-${var.env}"
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__cost_anomaly_sns_topic_policy"

  statement {
    sid = "AWSAnomalyDetectionSNSPublishingPermissions"

    actions = [
      "SNS:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.cost_anomaly_updates.arn
    ]
  }

  statement {
    sid = "__cost_anomaly_sns"

    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.cost_anomaly_updates.arn
    ]
  }
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.cost_anomaly_updates.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_ce_anomaly_subscription" "realtime_subscription" {
  name      = "realtime_cost_anomaly_subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.BCDA_Account_Monitor.arn
  ]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_anomaly_updates.arn
  }

  depends_on = [
    aws_sns_topic_policy.default
  ]

  threshold_expression {
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["150"]
      }
    }
    or {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
        match_options = ["GREATER_THAN_OR_EQUAL"]
        values        = ["30"]
      }
    }
  }
}


module "sns_to_slack_function" {
  source = "../../modules/function"

  app = "cdap"
  env = var.env

  name        = "Cost Anomaly Alert"
  description = "Listens for Cost Anomaly Alerts and forwards to Slack"

  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  environment_variables = {

    IGNORE_OK = true
  }
}

module "sns_to_slack_queue" {
  source = "../../modules/queue"

  name = "cost-anomaly-alert-queue"
  sns_topic_arn = "aws_sns_topic.cost_anomaly_updates.arn"

  function_name = module.sns_to_slack_function.name
}
