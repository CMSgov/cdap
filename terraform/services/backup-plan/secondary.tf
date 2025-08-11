
resource "aws_iam_role" "secondary_kms_admin_role" {
  name     = "KMSAdminRole"
  provider = aws.secondary
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_kms_key_policy" "secondary_backup_key_policy" {
  provider = aws.secondary
  key_id   = data.aws_kms_key.secondary_kms_key.key_id

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
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdminRole"
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
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdminRole"
          ]
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : data.aws_kms_alias.secondary_kms_alias.arn
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KMSAdminRole"
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
  name     = "alias/bcda-${var.env}"
}

data "aws_kms_key" "secondary_kms_key" {
  provider = aws.secondary
  key_id   = data.aws_kms_alias.secondary_kms_alias.target_key_id
}

resource "aws_backup_vault" "secondary_backup_vault" {
  provider    = aws.secondary
  name        = var.vault_name
  kms_key_arn = data.aws_kms_key.secondary_kms_key.arn
}

data "aws_iam_policy_document" "secondary_backup_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "backup:CopyIntoBackupVault",
    ]

    resources = [aws_backup_vault.secondary_backup_vault.arn]
  }
}

resource "aws_backup_vault_policy" "secondary_backup_vault_policy" {
  backup_vault_name = aws_backup_vault.secondary_backup_vault.name
  policy            = data.aws_iam_policy_document.secondary_backup_policy.json
}
