data "aws_iam_policy_document" "ssm_inline_test" {
  statement {
    sid    = "InlinePolicySSMRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [aws_ssm_parameter.inline_policy_test.arn]
  }
}
