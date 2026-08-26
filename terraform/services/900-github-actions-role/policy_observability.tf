data "aws_iam_policy_document" "github_actions_observability" {
  # CloudWatch Read
  statement {
    sid = "CloudwatchRead"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # CloudWatch Write
  statement {
    sid = "CloudwatchAlarmsWrite"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:SetAlarmState",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:*:*:alarm:${var.app}-${var.env}-*",
    ]
  }

  # Cloudwatch Logs Write
  statement {
    sid = "LogsWrite"
    actions = [
      "logs:AssociateKmsKey",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DeleteLogGroup",
      "logs:DeleteLogStream",
      "logs:DeleteSubscriptionFilter",
      "logs:DisassociateKmsKey",
      "logs:PutRetentionPolicy",
      "logs:PutSubscriptionFilter",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = [
      # ECS Container Insights
      # /aws/ecs/containerinsights/${app}-${env}*/performance
      "arn:aws:logs:*:*:log-group:/aws/ecs/containerinsights/${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:/aws/ecs/containerinsights/${var.app}-${var.env}*:*",

      # ECS Fargate — service level
      # /aws/ecs/fargate/${app}-${env}/${service}
      "arn:aws:logs:*:*:log-group:/aws/ecs/fargate/${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:/aws/ecs/fargate/${var.app}-${var.env}*:*",

      # ECS Fargate — sub-service level (e.g. datadog-agent sidecar)
      # /aws/ecs/fargate/${app}-${env}/${service}/${subservice}
      # Covered by the wildcard above since * matches the slash too...
      # actually NO — need explicit deeper pattern
      "arn:aws:logs:*:*:log-group:/aws/ecs/fargate/${var.app}-${var.env}/*/*",
      "arn:aws:logs:*:*:log-group:/aws/ecs/fargate/${var.app}-${var.env}/*/*:*",

      # Lambda
      # /aws/lambda/${app}-${env}-*
      "arn:aws:logs:*:*:log-group:/aws/lambda/${var.app}-${var.env}-*",
      "arn:aws:logs:*:*:log-group:/aws/lambda/${var.app}-${var.env}-*:*",

      # RDS
      # /aws/rds/cluster/${app}-${env}/postgresql
      # /aws/rds/instance/${app}-${env}*/postgresql
      "arn:aws:logs:*:*:log-group:/aws/rds/cluster/${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:/aws/rds/cluster/${var.app}-${var.env}*:*",
      "arn:aws:logs:*:*:log-group:/aws/rds/instance/${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:/aws/rds/instance/${var.app}-${var.env}*:*",

      # EventBridge ECS events
      # /aws/events/ecs/${app}-${env}-*
      "arn:aws:logs:*:*:log-group:/aws/events/ecs/${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:/aws/events/ecs/${var.app}-${var.env}*:*",

      # WAF — required prefix
      "arn:aws:logs:*:*:log-group:aws-waf-logs-${var.app}-${var.env}*",
      "arn:aws:logs:*:*:log-group:aws-waf-logs-${var.app}-${var.env}*:*",
    ]
  }

  # Logs Read
  statement {
    sid = "LogsRead"
    actions = [
      "logs:Describe*",
      "logs:GetLogGroupFields",
      "logs:List*",
    ]
    resources = ["*"]
  }
}