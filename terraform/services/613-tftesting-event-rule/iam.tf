data "aws_iam_policy_document" "roundtrip" {
  count = local.enabled ? 1 : 0

  statement {
    sid       = "PutTestEvents"
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:${module.platform.primary_region.name}:${module.platform.account_id}:event-bus/default"]

    condition {
      test     = "StringEquals"
      variable = "events:source"
      values   = [local.event_source]
    }
  }

  statement {
    sid       = "RecordReceipt"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [aws_ssm_parameter.receipt[0].arn]
  }
}
