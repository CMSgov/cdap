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
}

# Dedicated CMK so log encryption is managed and rotated independently of the
# app-env keys
resource "aws_kms_key" "log_retention" {
  description             = "Dedicated encryption key for the long-term log retention bucket"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.log_retention_kms.json
}

resource "aws_kms_alias" "log_retention" {
  name          = "alias/long-term-log-retention"
  target_key_id = aws_kms_key.log_retention.key_id
}

locals {
  # Wildcard matches the bucket_prefix-generated name, avoiding a 
  # dependency cycle between bucket policy and the bucket module
  log_bucket_arn_pattern = "arn:aws:s3:::${var.app}-${var.env}-long-term-log-retention-*"

  # Log sources that write directly to S3, bypassing Firehose
  s3_direct_log_writers = {
    cloudtrail = {
      sid       = "AllowCloudtrailWrites"
      principal = "cloudtrail.amazonaws.com"
      prefixes  = ["cloudtrail/"]
    }
    # VPC Flow Logs and CloudFront (Vended logs: natively published by AWS services on behalf of the customer)
    vended_log_delivery = {
      sid       = "AllowVendedLogDeliveryWrites"
      principal = "delivery.logs.amazonaws.com"
      prefixes  = ["vpc-flow-logs/", "cloudfront/"]
    }
    s3_access_logging = {
      sid       = "AllowS3AccessLoggingWrites"
      principal = "logging.s3.amazonaws.com"
      prefixes  = ["s3-access-logs/"]
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
      values   = [for w in local.s3_direct_log_writers : w.principal]
    }
  }

  statement {
    sid    = "AllowLogDeliveryAclChecks"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [for w in local.s3_direct_log_writers : w.principal]
    }

    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [local.log_bucket_arn_pattern]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [module.platform.account_id]
    }
  }

  dynamic "statement" {
    for_each = local.s3_direct_log_writers
    content {
      sid    = statement.value.sid
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = [statement.value.principal]
      }

      actions   = ["s3:PutObject"]
      resources = [for p in statement.value.prefixes : "${local.log_bucket_arn_pattern}/${p}*"]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [module.platform.account_id]
      }
    }
  }
}

module "log_bucket" {
  source = "../../modules/bucket"

  app  = var.app
  env  = var.env
  name = "${var.app}-${var.env}-long-term-log-retention"

  kms_key_arn        = aws_kms_key.log_retention.arn
  use_custom_kms_key = true

  # Compliance-mode WORM in prod only: objects cannot be deleted or overwritten
  # for 6 years by anyone, including root (HIPAA retention requirement).
  # No lock in test environments
  object_lock = var.env == "prod" ? {
    mode  = "COMPLIANCE"
    years = 6
  } : null
  force_destroy = false

  # Writers are limited to the Firehose role and prefix-scoped log delivery
  # services. all other principals are denied
  additional_bucket_policies = [data.aws_iam_policy_document.log_bucket_writes.json]

  # GLACIER_IR keeps objects queryable via Athena, unlike GLACIER or
  # DEEP_ARCHIVE which require restore before read
  # TODO: determine if we should use GLACIER_IR or GLACIER for long-term storage
  transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    },
    {
      days          = 365
      storage_class = "GLACIER_IR"
    },
  ]

  # Expire objects once the 6-year HIPAA retention has elapsed
  # in prod this is also past the Object Lock retain-until date. Noncurrent
  # versions and delete markers are cleaned up by the bucket module shortly after.
  expiration_days = 2200

  ssm_parameter = "/cdap/${var.env}/common/nonsensitive/long-term-log-retention/bucket"
}
