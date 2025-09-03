data "aws_caller_identity" "current" {}

resource "aws_ce_anomaly_monitor" "BCDA_Account_Monitor" {
  name              = "BCDA Account Monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

module "cost_anomaly_sns" {
  source      = "../../modules/topic"
  name        = "cost-anomaly-updates"
  policy_service_identifiers = ["costalerts.amazonaws.com"]
}


resource "aws_ce_anomaly_subscription" "realtime_subscription" {
  name      = "realtime_cost_anomaly_subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.BCDA_Account_Monitor.arn
  ]

  subscriber {
    type    = "SNS"
    address = module.cost_anomaly_sns.arn
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

  name          = "cost-anomaly-alert-queue"
  sns_topic_arn = module.cost_anomaly_sns.arn

  function_name = module.sns_to_slack_function.name
}
