# Applied in the dasg insights account. Grants quicksight read access to the
# bb2 export bucket in cdap-prod

data "aws_caller_identity" "current" {}

# cdap-prod account where the bb-prod key lives
data "aws_ssm_parameter" "cdap_prod_account_id" {
  name = "/cdap/mgmt/insights/sensitive/production-account" #TODO: rename and add to SOPs
}

locals {
  # placeholder until the export bucket is applied
  export_bucket_name = "bb2-prod-quicksight-export"
  export_bucket_arn  = "arn:aws:s3:::${local.export_bucket_name}"
}

data "aws_iam_policy_document" "quicksight_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["quicksight.amazonaws.com"]
    }

    # only QS in this account may assume
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "bb2_quicksight" {
  name               = "bb2-quicksight-export-read"
  description        = "Quicksight readonly access to bb2 insights export bucket in cdap-prod"
  assume_role_policy = data.aws_iam_policy_document.quicksight_trust.json
}

data "aws_iam_policy_document" "read_export_bucket" {
  statement {
    sid       = "ListExportBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.export_bucket_arn]
  }

  statement {
    sid       = "ReadExportObjects"
    actions   = ["s3:GetObject"]
    resources = ["${local.export_bucket_arn}/*"]
  }

  # objects are encrypted with shared bb-prod key
  statement {
    sid = "DecryptExportObjects"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["arn:aws:kms:us-east-1:${data.aws_ssm_parameter.cdap_prod_account_id.value}:key/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:ResourceAliases"
      values   = ["alias/bb-prod"]
    }
  }
}

resource "aws_iam_role_policy" "read_export_bucket" {
  name   = "bb2-export-bucket-read"
  role   = aws_iam_role.bb2_quicksight.id
  policy = data.aws_iam_policy_document.read_export_bucket.json
}

