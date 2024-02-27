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
    # Spaces are allowed in SIDs for key policies
    sid = "Enable IAM User Permissions"

    actions = ["kms:*"]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.buckets) > 0 ? [1] : []
    content {
      sid = "Allow S3 buckets to publish to an encrypted SNS topic"

      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]

      principals {
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }

      resources = [aws_kms_key.this.arn]

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = var.buckets
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.sns_topics) > 0 ? [1] : []
    content {
      sid = "Allow SNS topics to send messages to an encrypted SQS queue"

      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]

      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }

      resources = [aws_kms_key.this.arn]

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
