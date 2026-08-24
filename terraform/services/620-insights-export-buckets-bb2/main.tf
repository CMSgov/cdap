data "aws_ssm_parameter" "bb_account_id" {
  name = "/cdap/prod/external/bb/sensitive/aws_account_id"
}

# Execution role granted KMS access by 410-external-kms
data "aws_ssm_parameter" "bb_lambda_role_arn" {
  name = "/cdap/prod/external/bb/sensitive/lambda_role_arn"
}

# QuickSight lives in DASG Insights account. Default service role name is fixed
data "aws_ssm_parameter" "dasg_insights_account_id" {
  name = "/cdap/prod/external/dasg_insights/sensitive/aws_account_id"
}

locals {
  quicksight_role_arn = "arn:aws:iam::${data.aws_ssm_parameter.dasg_insights_account_id.value}:role/service-role/aws-quicksight-service-role-v0"
}

# Key shared with bb via 410-external-kms
data "aws_kms_alias" "bb" {
  name = "alias/bb-prod"
}

data "aws_iam_policy_document" "bb2_export_bucket_access" {
  statement {
    sid = "AllowBB2LambdaUploads"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_ssm_parameter.bb_account_id.value}:root"]
    }

    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
    ]

    resources = [
      module.quicksight_export.arn,
      "${module.quicksight_export.arn}/*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [data.aws_ssm_parameter.bb_lambda_role_arn.value]
    }
  }

  statement {
    sid = "AllowQuickSightReads"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_ssm_parameter.dasg_insights_account_id.value}:root"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      module.quicksight_export.arn,
      "${module.quicksight_export.arn}/*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [local.quicksight_role_arn]
    }
  }

  statement {
    sid    = "DenyIncorrectKmsKey"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${module.quicksight_export.arn}/*"]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [data.aws_kms_alias.bb.target_key_arn]
    }
  }

  statement {
    sid    = "DenyNonKmsEncryption"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${module.quicksight_export.arn}/*"]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

module "quicksight_export" {
  source = "../../modules/bucket"

  app         = "cdap"
  env         = "prod"
  name        = "bb2-prod-quicksight-export"
  kms_key_arn = data.aws_kms_alias.bb.target_key_arn

  additional_bucket_policies = [data.aws_iam_policy_document.bb2_export_bucket_access.json]
}
