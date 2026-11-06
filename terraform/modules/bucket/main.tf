locals {
  effective_kms_key_arn = var.use_custom_kms_key ? var.kms_key_arn : data.aws_kms_alias.default_encryption_key[0].target_key_arn

  # Delivery source/destination names are capped at 60 characters, so use the
  # stable name prefix rather than the generated bucket name
  access_logging_name = "${substr(var.name, 0, 36)}-s3-access-logs"
}
resource "aws_s3_bucket" "this" {
  # Max length on bucket_prefix is 37, so cut it to 36 plus the dash
  bucket_prefix = "${substr(var.name, 0, 36)}-"
  force_destroy = var.force_destroy

  # Object Lock can only be enabled at bucket creation
  object_lock_enabled = var.object_lock != null
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.object_lock != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode  = var.object_lock.mode
      years = var.object_lock.years
    }
  }
}

resource "aws_ssm_parameter" "bucket" {
  count = var.ssm_parameter != null ? 1 : 0
  name  = var.ssm_parameter
  value = aws_s3_bucket.this.id
  type  = "String"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_kms_alias" "default_encryption_key" {
  count = var.use_custom_kms_key ? 0 : 1
  name  = "alias/${var.app}-${var.env}"
}

data "aws_iam_policy_document" "ssl_only" {
  statement {
    sid = "AllowSSLRequestsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = concat(
    [data.aws_iam_policy_document.ssl_only.json],
    var.additional_bucket_policies,
  )
  dynamic "statement" {
    for_each = var.additional_bucket_statements
    content {
      sid = statement.value.sid
      principals {
        type        = "AWS"
        identifiers = statement.value.principals
      }
      actions   = statement.value.actions
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.effective_kms_key_arn
    }
  }
}

# access logging: bucket -> per-bucket log group -> subscription filter -> shared
# Firehose -> log-retention bucket (under cloudwatch/aws/s3/access-logs/<bucket>/).
# This is the default route. Only the log-retention bucket itself opts 
# out with access_logging = "external", configuring its own direct delivery to CMS
# bucket to avoid looping its own access logs.

# Encrypted with the caller's platform primary key
module "access_logs_group" {
  count  = var.access_logging == "cloudwatch" ? 1 : 0
  source = "../cloudwatch_log_group"

  name = "/aws/s3/access-logs/${aws_s3_bucket.this.id}"
  env  = var.env
  # CloudWatch Logs requires a key ARN (not an alias ARN)
  kms_key_id = var.platform.kms_alias_primary.target_key_arn
}

resource "aws_cloudwatch_log_delivery_source" "access_logs" {
  count = var.access_logging == "cloudwatch" ? 1 : 0

  name         = local.access_logging_name
  log_type     = "S3_SERVER_ACCESS_LOGS"
  resource_arn = aws_s3_bucket.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "access_logs" {
  count = var.access_logging == "cloudwatch" ? 1 : 0

  name          = local.access_logging_name
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = module.access_logs_group[0].this.arn
  }
}

resource "aws_cloudwatch_log_delivery" "access_logs" {
  count = var.access_logging == "cloudwatch" ? 1 : 0

  delivery_source_name     = aws_cloudwatch_log_delivery_source.access_logs[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.access_logs[0].arn
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "noncurrent-ia"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  rule {
    id     = "cleanup-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = length(var.transitions) > 0 ? [1] : []
    content {
      id     = "transitions"
      status = "Enabled"

      filter {}

      dynamic "transition" {
        for_each = var.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.expiration_days != null ? [var.expiration_days] : []
    content {
      id     = "retention-expiration"
      status = "Enabled"

      filter {}

      expiration {
        days = rule.value
      }

      # Expiration above only creates a delete marker; this deletes the
      # noncurrent version shortly after so data is actually removed
      noncurrent_version_expiration {
        noncurrent_days = 30
      }
    }
  }

  # ExpiredObjectDeleteMarker cannot share a rule with days-based expiration
  dynamic "rule" {
    for_each = var.expiration_days != null ? [1] : []
    content {
      id     = "cleanup-delete-markers"
      status = "Enabled"

      filter {}

      expiration {
        expired_object_delete_marker = true
      }
    }
  }
}
