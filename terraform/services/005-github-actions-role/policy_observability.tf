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
    sid = "CloudwatchWrite"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:SetAlarmState",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    actions = [
      "logs:AssociateKmsKey",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:CreateLogStream",
      "logs:PutRetentionPolicy",
      "logs:PutSubscriptionFilter",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["*"] # FIXME Make this specific to app-env, ensuring creation for API WAF as well as other standard app-env path
  }

  statement {
    actions = [
      "logs:Describe*",
      "logs:List*",
      "logs:CreateLogStream",
      "logs:GetLogGroupFields",

    ]
    resources = ["*"]
  }
}
