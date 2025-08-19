data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "aurora_export" {
  statement {
    actions = [
      "s3:ListAllMyBuckets",
    ]
    resources = [
      "*"
    ]
  }
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      module.export_bucket.arn,
    ]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "${module.export_bucket.arn}/*"
    ]
  }
}

data "aws_kms_alias" "aurora_export_kms_alias" {
  name     = lower("alias/bcda-${var.env}")
}

data "aws_kms_key" "aurora_export" {
  key_id   = data.aws_kms_alias.aurora_export_kms_alias.target_key_id
}
