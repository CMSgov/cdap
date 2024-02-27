module "topic_key" {
  source      = "../key"
  name        = "${var.name}-topic"
  description = "For ${var.name} SNS topic"
  buckets     = var.buckets
}

resource "aws_sns_topic" "this" {
  name = var.name

  kms_master_key_id = module.topic_key.id
}

data "aws_iam_policy_document" "topic" {
  count = length(var.buckets) > 0 ? 1 : 0
  statement {
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.this.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = var.buckets
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = data.aws_iam_policy_document.topic[0].json
}
