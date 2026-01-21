data "aws_caller_identity" "this" {}

data "aws_region" "primary" {}

resource "aws_s3_bucket" "this" {
  # Max length on bucket_prefix is 37, so cut it to 36 plus the dash
  bucket_prefix = "${substr(var.name, 0, 36)}-"
  force_destroy = true
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


data "aws_kms_alias" "kms_key" {
  name = "alias/${var.app}-${var.env}"
}

data "aws_iam_policy_document" "this" {
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

  # Bucket policy to allow promotion of artifacts by deploy roles in upper environments
  dynamic "statement" {
    for_each = length(var.cross_account_read_roles) > 0 ? [1] : []
    content {
      sid = "CrossAccountRead"

      principals {
        type        = "AWS"
        identifiers = var.cross_account_read_roles
      }

      actions = [
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionTagging",
        "s3:ListBucket",
      ]

      resources = [
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*",
      ]
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
      kms_master_key_id = data.aws_kms_alias.kms_key.target_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

data "aws_iam_account_alias" "current" {}

data "aws_s3_bucket" "bucket_access_logs" {
  bucket = "cms-cloud-${data.aws_caller_identity.this.account_id}-${data.aws_region.primary.name}-access-logs"
}

resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = data.aws_s3_bucket.bucket_access_logs.id
  target_prefix = "${aws_s3_bucket.this.id}/"
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
}
