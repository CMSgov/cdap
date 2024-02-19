resource "aws_kms_key" "this" {
  description         = var.description
  enable_key_rotation = true
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "this" {
  # https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html
  statement {
    sid = "Enable IAM User Permissions"

    actions = ["kms:*"]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.sns_topics) > 0 ? [1] : []
    content {
      # Spaces are allowed in SIDs for key policies
      sid = "Allow SNS topics to send messages to an encrypted SQS queue"

      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]

      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }

      resources = [aws_kms_key.queue.arn]

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = var.sns_topics
      }
    }
  }
}

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.id
  policy = data.aws_iam_policy_document.this.json
}
