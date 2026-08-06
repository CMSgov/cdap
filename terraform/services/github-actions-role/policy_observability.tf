data "aws_iam_policy_document" "github_actions_observability" {
  # CloudWatch
  statement {
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:SetAlarmState",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
    ]
    resources = ["*"] # FIXME Make this specific to app-env, ensuring creation for API WAF as well as other standard app-env path
  }

  statement {
    actions = [
      "logs:Describe*",
      "logs:List*",
      "logs:CreateLogStream",
    ]
    resources = ["*"]
  }
}
