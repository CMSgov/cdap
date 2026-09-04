# Applied in the dasg insights account. Grants QuickSight read access to the
# bb export bucket in cdap-prod. The bucket is created via the shared
# "insights" terraservice and encrypted with the shared aurora_export KMS
# key (also used by ab2d, dpc, and bcda's export buckets).

data "aws_caller_identity" "current" {}

# cdap-prod account where the aurora_export key and bb's bucket live
data "aws_ssm_parameter" "cdap_prod_account_id" {
  name = "/cdap/mgmt/insights/sensitive/production-account" #TODO: rename and add to SOPS
}

locals {
  # modules/bucket uses bucket_prefix, so the deployed bucket name carries an
  # AWS-generated random suffix we can't know at plan time. Match by prefix.
  export_bucket_arn_pattern = "arn:aws:s3:::bb-prod-aurora-export-*"
}

data "aws_iam_policy_document" "quicksight_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["quicksight.amazonaws.com"]
    }

    # only QuickSight in this account may assume
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "bb2_quicksight" {
  name               = "bb2-quicksight-export-read"
  description        = "QuickSight readonly access to bb insights export bucket in cdap-prod"
  assume_role_policy = data.aws_iam_policy_document.quicksight_trust.json
}

data "aws_iam_policy_document" "read_export_bucket" {
  statement {
    sid       = "ListExportBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.export_bucket_arn_pattern]
  }

  statement {
    sid       = "ReadExportObjects"
    actions   = ["s3:GetObject"]
    resources = ["${local.export_bucket_arn_pattern}/*"]
  }

  # objects are encrypted with the shared aurora_export key
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
      values   = ["alias/aurora_export"]
    }
  }
}

resource "aws_iam_role_policy" "read_export_bucket" {
  name   = "bb2-export-bucket-read"
  role   = aws_iam_role.bb2_quicksight.id
  policy = data.aws_iam_policy_document.read_export_bucket.json
}

