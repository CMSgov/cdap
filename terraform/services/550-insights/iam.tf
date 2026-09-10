data "aws_iam_policy_document" "aurora_export_kms" {
  statement {
    sid = "EnablePRODAccountAccess"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${module.standards.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Currently broadly allows the Insights account to manage refined IAM
  # Can be changed to scope for only the roles that have permissions
  statement {
    sid = "EnableDASGInsightsAccountAccess"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_ssm_parameter.dasg_insights_account_id.value}:root"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowAttachmentOfPersistentResources"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_ssm_parameter.dasg_insights_account_id.value}:root"]
    }
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # Internal writers: same AWS account as the key
  statement {
    sid = "AllowInternalAuroraExportWriters"
    principals {
      type        = "AWS"
      identifiers = [for k, v in local.internal_writers : v.internal_role_arn]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }

  # External writers: genuinely different AWS accounts (e.g. bfd-legacy for
  # BB)
  dynamic "statement" {
    for_each = local.external_writers
    content {
      sid = "Enable${title(statement.value.app)}AccountAccess"
      principals {
        type = "AWS"
        identifiers = [
          data.aws_ssm_parameter.external_writer_role[statement.value.external_role_path].value
        ]
      }
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
      "kms:DescribeKey"]
      resources = ["*"]
    }
  }
}
