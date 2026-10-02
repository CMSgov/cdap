locals {
  # Wildcard matches the bucket_prefix-generated name, avoiding a
  # dependency cycle between bucket policy and the bucket module
  log_bucket_arn_pattern = "arn:aws:s3:::${local.shared_name}-*"

  # Vended logs (VPC Flow Logs, CloudFront) are published by AWS directly to
  # S3, bypassing Firehose. CloudTrail is excluded as ours is CMS-managed
  vended_delivery_principal = "delivery.logs.amazonaws.com"
  vended_delivery_prefixes = [
    "vpc-flow-logs/",
    "cloudfront/",
  ]
}

data "aws_iam_policy_document" "log_retention_kms" {
  statement {
    sid    = "EnableRootAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${module.platform.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${module.platform.primary_region.region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${module.platform.primary_region.region}:${module.platform.account_id}:log-group:/aws/kinesisfirehose/${local.shared_name}"]
    }
  }

  # Vended delivery encrypts with the bucket's default key
  statement {
    sid    = "AllowVendedLogDeliveryEncryption"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.vended_delivery_principal]
    }

    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }
  }
}

data "aws_iam_policy_document" "log_bucket_writes" {
  statement {
    sid    = "DenyWritesExceptLogDelivery"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${local.log_bucket_arn_pattern}/*"]

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.firehose.arn]
    }

    # PrincipalServiceName is absent for IAM principals, so they stay denied
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = [local.vended_delivery_principal]
    }
  }

  statement {
    sid    = "AllowLogDeliveryAclChecks"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.vended_delivery_principal]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [local.log_bucket_arn_pattern]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }
  }

  statement {
    sid    = "AllowVendedLogDeliveryWrites"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [local.vended_delivery_principal]
    }

    actions   = ["s3:PutObject"]
    resources = [for p in local.vended_delivery_prefixes : "${local.log_bucket_arn_pattern}/${p}*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }
  }
}

# Firehose -> S3 delivery role, write access limited to the data/error prefixes
data "aws_iam_policy_document" "firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [module.platform.account_id]
    }
  }
}

data "aws_iam_policy_document" "firehose_delivery" {
  statement {
    sid = "BucketMetadata"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [module.log_bucket.arn]
  }
  statement {
    sid = "PrefixLimitedWrites"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "${module.log_bucket.arn}/${local.firehose_data_prefix}*",
      "${module.log_bucket.arn}/${local.firehose_error_prefix}*",
    ]
  }

  statement {
    sid = "EncryptWithDedicatedKey"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.log_retention.arn]
  }

  statement {
    sid       = "DeliveryErrorLogging"
    actions   = ["logs:PutLogEvents"]
    resources = ["${module.firehose_log_group.this.arn}:log-stream:${aws_cloudwatch_log_stream.firehose_s3_delivery.name}"]
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${local.cdap_name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
}

resource "aws_iam_role_policy" "firehose" {
  name   = "${local.cdap_name}-s3-delivery"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose_delivery.json
}

# CloudWatch Logs -> Firehose role, assumed by subscription filters
data "aws_iam_policy_document" "cloudwatch_to_firehose_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${module.platform.primary_region.region}:${module.platform.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_to_firehose" {
  statement {
    sid = "PutToLogRetentionFirehose"
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
    ]
    resources = [aws_kinesis_firehose_delivery_stream.log_retention.arn]
  }
}

resource "aws_iam_role" "cloudwatch_to_firehose" {
  name               = "${local.shared_name}-subscription"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_to_firehose_assume.json
}

resource "aws_iam_role_policy" "cloudwatch_to_firehose" {
  name   = "${local.shared_name}-firehose-put"
  role   = aws_iam_role.cloudwatch_to_firehose.id
  policy = data.aws_iam_policy_document.cloudwatch_to_firehose.json
}
