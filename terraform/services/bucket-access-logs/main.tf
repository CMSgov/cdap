resource "aws_s3_bucket" "bucket_access_logs" {
  bucket_prefix = "bucket-access-logs-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      # Encryption must be AES256. See the final bullet in the alert box at the top of
      # https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "bucket_access_logs" {
  statement {
    sid = "AllowSSLRequestsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.bucket_access_logs.arn,
      "${aws_s3_bucket.bucket_access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid = "S3ServerAccessLogsPolicy"

    effect = "Allow"

    principals {
      identifiers = ["logging.s3.amazonaws.com"]
      type        = "Service"
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.bucket_access_logs.bucket}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id
  policy = data.aws_iam_policy_document.bucket_access_logs.json
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_access_logs" {
  bucket = aws_s3_bucket.bucket_access_logs.id

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

resource "aws_ssm_parameter" "bucket_access_logs" {
  name        = " /cdap/sensitive/bucket-access-logs-bucket "
  value       = aws_s3_bucket.bucket_access_logs.id
  type        = "String"
  description = "S3 bucket for storing access logs from other buckets"
}
