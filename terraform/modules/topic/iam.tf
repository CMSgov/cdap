locals {
  sns_topic_has_policy_statements = (
    var.allow_cloudwatch_publish ||
    var.allow_eventbridge_publish ||
    length(var.additional_publisher_service_principals) > 0 ||
    length(var.additional_publisher_iam_arns) > 0 ||
    length(var.buckets) > 0
  )
}

resource "aws_sns_topic_policy" "this" {
  count  = local.sns_topic_has_policy_statements ? 1 : 0
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this.json
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = var.allow_cloudwatch_publish ? [1] : []
    content {
      sid    = "AllowCloudWatchPublish"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["cloudwatch.amazonaws.com"]
      }

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [var.platform.aws_caller_identity.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = var.allow_eventbridge_publish ? [1] : []
    content {
      sid    = "AllowEventBridgePublish"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [var.platform.aws_caller_identity.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = toset(var.additional_publisher_service_principals)
    content {
      sid    = "AllowPublish${replace(statement.value, "/[^A-Za-z0-9]/", "")}"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = [statement.value]
      }

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [var.platform.aws_caller_identity.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = toset(var.additional_publisher_iam_arns)
    content {
      sid    = "AllowPublish${substr(md5(statement.value), 0, 12)}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.buckets) > 0 ? [1] : []
    content {
      sid    = "AllowS3BucketNotifications"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]

      condition {
        test     = "ArnLike"
        variable = "aws:SourceArn"
        values   = var.buckets
      }
    }
  }
}

# Role SNS assumes to write delivery status logs
data "aws_iam_policy_document" "delivery_status_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.platform.aws_caller_identity.account_id]
    }
  }
}

data "aws_iam_policy_document" "delivery_status_logs" {
  statement {
    sid = "WriteDeliveryStatusLogs"
    # No logs:CreateLogGroup. Log groups are Terraform-managed so drift fails loudly
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${module.delivery_logs.this.arn}:*",
      "${module.delivery_failure_logs.this.arn}:*",
    ]
  }
}

resource "aws_iam_role" "delivery_status" {
  name               = "${local.topic_name}-sns-delivery-status"
  path               = "/delegatedadmin/developer/"
  assume_role_policy = data.aws_iam_policy_document.delivery_status_assume.json
}

resource "aws_iam_role_policy" "delivery_status" {
  name   = "${local.topic_name}-delivery-status-logs"
  role   = aws_iam_role.delivery_status.id
  policy = data.aws_iam_policy_document.delivery_status_logs.json
}
