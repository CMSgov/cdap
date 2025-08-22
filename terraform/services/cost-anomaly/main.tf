resource "aws_sns_topic" "cost_anomaly_alerts" {
  name = "cost-anomaly-alerts-topic"
}

resource "aws_sns_topic_policy" "cost_anomaly_topic_policy" {
  arn    = aws_sns_topic.cost_anomaly_alerts.arn
  policy = data.aws_iam_policy_document.cost_anomaly_topic_access.json
}

data "aws_iam_policy_document" "cost_anomaly_topic_access" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ce.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.cost_anomaly_alerts.arn]
  }
}

resource "aws_ce_anomaly_monitor" "all_services_monitor" {
  name              = "all-services-cost-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "cost_anomaly_subscription" {
  name             = "cost-anomaly-alerts-subscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.all_services_monitor.arn]
  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_anomaly_alerts.arn
  }
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["150"]
    }
  }
}