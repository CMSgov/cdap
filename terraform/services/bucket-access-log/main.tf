resource "aws_s3_bucket" "bucket-access_logs" {
  bucket        = "${var.app}-${var.env}-bucket-access-log"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket-access_logs" {
  bucket = aws_s3_bucket.bucket-access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket-access_logs" {
  bucket = aws_s3_bucket.bucket-access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

data "aws_iam_policy_document" "bucket-access_logs" {
  statement {
    sid = "AllowSSLRequestsOnly"

    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.bucket-access_logs.arn,
      "${aws_s3_bucket.bucket-access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.bucket-access_logs.id
  policy = data.aws_iam_policy_document.bucket-access_logs.json
}
