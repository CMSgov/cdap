data "aws_iam_policy_document" "sqs_trigger" {
  statement {
    sid = "SQSTriggerReceive"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [module.sns_to_slack_queue.arn]
  }
}

data "aws_iam_policy_document" "sqs_queue_policy" {
  statement {
    sid    = "allow_sns_access"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "SQS:SendMessage",
    ]

    resources = [
      module.sns_to_slack_queue.arn
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:sns:${module.platform.primary_region.name}:${module.platform.account_id}:*"
      ]
    }
  }
}
