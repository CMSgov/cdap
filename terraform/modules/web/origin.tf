/* To reduce module nesting and adhere to current configurations, S3 buckets are managed outside of this module.
Permissions for Cloudfront, however, are managed here.  */

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  count  = var.origin_bucket.arn == null ? 0 : 1
  bucket = var.origin_bucket.id
  policy = data.aws_iam_policy_document.allow_cloudfront_access[0].json
}

# S3 static site host bucket policy document
data "aws_iam_policy_document" "allow_cloudfront_access" {
  # There are no dev or test environments for the static site
  count = var.origin_bucket.arn == null ? 0 : 1

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
      var.origin_bucket.arn
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

