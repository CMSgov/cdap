resource "aws_kms_key_policy" "secondary_backup_key_policy" {
  provider = aws.secondary
  for_each = toset(local.apps)
  key_id   = data.aws_kms_key.secondary_kms_key[each.value].key_id

  policy = jsonencode({
    Id = "secondary_backup_key_policy"
    Statement = [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          ]
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow access for Key Administrators",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
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
        "Resource" : "*"
      },
      {
        "Sid" : "Allow use of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : data.aws_kms_alias.secondary_kms_alias[each.value].arn
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
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

data "aws_kms_alias" "secondary_kms_alias" {
  provider = aws.secondary
  for_each = toset(local.apps)
  name     = lower("alias/${each.value}-${var.env}")
}

data "aws_kms_key" "secondary_kms_key" {
  provider = aws.secondary
  for_each = toset(local.apps)
  key_id   = data.aws_kms_alias.secondary_kms_alias[each.value].target_key_id
}

resource "aws_backup_vault" "secondary_backup_vault" {
  provider    = aws.secondary
  for_each    = toset(local.apps)
  name        = "${var.vault_name}_${each.value}_cr"
  kms_key_arn = data.aws_kms_key.secondary_kms_key[each.value].arn
}

data "aws_iam_policy_document" "secondary_backup_policy" {
  provider = aws.secondary
  for_each = toset(local.apps)
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "backup:CopyIntoBackupVault",
    ]

    resources = [aws_backup_vault.secondary_backup_vault[each.value].arn]
  }
}

resource "aws_backup_vault_policy" "secondary_backup_vault_policy" {
  provider          = aws.secondary
  for_each          = toset(local.apps)
  backup_vault_name = aws_backup_vault.secondary_backup_vault[each.value].name
  policy            = data.aws_iam_policy_document.secondary_backup_policy[each.value].json
}

resource "aws_backup_vault_lock_configuration" "secondary_vault_lock" {
  provider            = aws.secondary
  for_each            = toset(local.apps)
  backup_vault_name   = aws_backup_vault.secondary_backup_vault[each.value].name
  changeable_for_days = 3
  max_retention_days  = 90
  min_retention_days  = 1
}
