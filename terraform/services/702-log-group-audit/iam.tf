data "aws_iam_policy_document" "discovery" {
  statement {
    sid = "LogGroupDiscovery"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeSubscriptionFilters",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TagDiscovery"
    actions   = ["tag:GetResources"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "results_write" {
  statement {
    sid       = "ResultsWrite"
    actions   = ["s3:PutObject"]
    resources = ["${module.results_bucket.arn}/${local.results_prefix}*"]
  }
}

data "aws_iam_policy_document" "alarm_publish" {
  statement {
    sid       = "AlarmPublish"
    actions   = ["sns:Publish"]
    resources = [data.aws_ssm_parameter.alarms_topic_arn.value]
  }
}

data "aws_iam_policy_document" "log_group_audit" {
  source_policy_documents = [
    data.aws_iam_policy_document.discovery.json,
    data.aws_iam_policy_document.results_write.json,
    data.aws_iam_policy_document.alarm_publish.json,
  ]
}
