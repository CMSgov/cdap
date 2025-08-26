resource "aws_kms_key_policy" "primary_backup_key_policy" {
  for_each = toset(local.apps)
  key_id   = data.aws_kms_key.primary_kms_key[each.value].key_id

  policy = jsonencode({
    Id = "primary_backup_key_policy"
    Statement = [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${module.standards.account_id}:root",
          ]
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Grant backup role access to kms actions.",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
        },
        "Action" : [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        "Resource" : data.aws_kms_alias.primary_kms_alias[each.value].arn
      },
      {
        "Sid" : "Allow use of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
          ]
        },
        "Action" : [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}

data "aws_kms_alias" "primary_kms_alias" {
  for_each = toset(local.apps)
  name     = lower("alias/${each.value}-${var.env}")
}

data "aws_kms_key" "primary_kms_key" {
  for_each = toset(local.apps)
  key_id   = data.aws_kms_alias.primary_kms_alias[each.value].target_key_id
}

resource "aws_backup_vault" "primary_backup_vault" {
  for_each    = toset(local.apps)
  name        = "${var.vault_name}_${each.value}"
  kms_key_arn = data.aws_kms_key.primary_kms_key[each.value].arn
}

data "aws_iam_policy_document" "primary_backup_policy" {
  for_each = toset(local.apps)
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [module.standards.account_id]
    }

    actions = [
      "backup:CopyIntoBackupVault",
    ]

    resources = [aws_backup_vault.primary_backup_vault[each.value].arn]
  }
}

resource "aws_backup_vault_policy" "primary_backup_vault_policy" {
  for_each          = toset(local.apps)
  backup_vault_name = aws_backup_vault.primary_backup_vault[each.value].name
  policy            = data.aws_iam_policy_document.primary_backup_policy[each.value].json
}

resource "aws_backup_plan" "aws_backup_plan" {
  for_each = toset(local.apps)
  name     = "cdap_managed_backup_plan_${each.value}"
  #only the 4hr rule should be copied to secondary
  rule {
    rule_name         = "4Hourly_1"
    target_vault_name = aws_backup_vault.primary_backup_vault[each.value].name
    schedule          = "cron(0 */4 * * ? *)"
    start_window      = 60
    completion_window = 180
    copy_action {
      destination_vault_arn = aws_backup_vault.secondary_backup_vault[each.value].arn
    }

    lifecycle {
      delete_after = 1
    }
  }

  rule {
    rule_name         = "Daily_7"
    target_vault_name = aws_backup_vault.primary_backup_vault[each.value].name
    schedule          = "cron(0 4 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "Weekly_35"
    target_vault_name = aws_backup_vault.primary_backup_vault[each.value].name
    schedule          = "cron(0 0 ? * SAT *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 35
    }
  }

  rule {
    rule_name         = "Monthly_90"
    target_vault_name = aws_backup_vault.primary_backup_vault[each.value].name
    schedule          = "cron(0 0 1 * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 90
    }
  }

}

resource "aws_backup_selection" "this" {
  for_each = toset(local.apps)
  # This iam role is the one CMS is using for their backup plan.
  iam_role_arn = "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
  name         = "cdap_managed_backup_selection_${each.value}"
  plan_id      = aws_backup_plan.aws_backup_plan[each.value].id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "AWS_Backup"
    value = "4Hours1_Daily7_Weekly35_Monthly90"
  }
}

resource "aws_backup_vault_lock_configuration" "primary_vault_lock" {
  for_each           = toset(local.apps)
  backup_vault_name  = aws_backup_vault.primary_backup_vault[each.value].name
  max_retention_days = 90
  min_retention_days = 1
}
