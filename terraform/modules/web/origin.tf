module "origin_bucket" {
  source = "../bucket"
  app    = var.platform.app
  env    = var.platform.env
  name   = var.domain_name
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = one(module.origin_bucket[*].id)
  policy = data.aws_iam_policy_document.allow_cloudfront_access.json
}

# S3 static site host bucket policy document
data "aws_iam_policy_document" "allow_cloudfront_access" {
  # There are no dev or test environments for the static site

  statement {
    sid    = "AllowCloudfrontAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.this.arn
      ]
    }

    resources = [
      var.origin_bucket.arn,
      "${var.origin_bucket.arn}/*",
    ]
  }
  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      var.origin_bucket.arn,
      "${var.origin_bucket.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

