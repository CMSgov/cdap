data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "aurora_export" {
  provider = aws
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:AbortMultipartUpload",
    ]
    effect = "Allow"
    resources = [
      "${module.export_bucket.arn}/*"
    ]
  }
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetBucketLocation",
      "s3:AbortMultipartUpload",
    ]
    effect = "Allow"
    resources = [
      module.export_bucket.arn,
    ]
  }
}
