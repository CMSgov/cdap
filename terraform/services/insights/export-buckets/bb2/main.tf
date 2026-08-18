data "aws_ssm_parameter" "bb_account_id" {
  name = "/cdap/${var.env}/external/bb/sensitive/aws_account_id"
}

locals {
  bb2_lambda_role_arn_pattern = "arn:aws:iam::${data.aws_ssm_parameter.bb_account_id.value}:role/service-role/bb2-lambda-create-tables-for-quicksight-role-*"
}

data "aws_kms_alias" "aurora_export" {
  name = "alias/aurora_export"
}

data "aws_iam_policy_document" "allow_bb2_lambda_uploads" {
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
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.bb2_lambda_role_arn_pattern]
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
      values   = [data.aws_kms_alias.aurora_export.target_key_arn]
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
  source = "../../../../modules/bucket"

  app         = "cdap"
  env         = var.env
  name        = "bb2-${var.env}-quicksight-export"
  kms_key_arn = data.aws_kms_alias.aurora_export.target_key_arn

  additional_bucket_policies = [data.aws_iam_policy_document.allow_bb2_lambda_uploads.json]
}
