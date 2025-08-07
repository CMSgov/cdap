# Secondary Region Resources
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "kms_admin_role" {
  name = "KMSAdminRole"

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

#TODO THIS should be a policy for key bcda-env
resource "aws_kms_key" "aws_kms_key" {
  description         = "KMS Key for Backup"
  enable_key_rotation = true
  policy              = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "key-consolepolicy-3",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kms_admin_role",
            },
            "Action": [
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
            "Resource": "*"
        },
        {
            "Sid": "Allow use of the key",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kms_admin_role"
                ]
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow attachment of persistent resources",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "${data.aws_caller_identity.current.account_id}",
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/kms_admin_role"
                ]
            },
            "Action": [
                "kms:CreateGrant",
                "kms:ListGrants",
                "kms:RevokeGrant"
            ],
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_kms_alias" "aws_kms_alias" {
  name          = "bcda-${var.env}"
  target_key_id = aws_kms_key.aws_kms_key.key_id
}

resource "aws_backup_vault" "aws_backup_vault" {
  name        = var.vault_name
  kms_key_arn = aws_kms_key.aws_kms_key.arn
}

resource "aws_backup_vault_policy" "aws_backup_vault_policy" {
  backup_vault_name = aws_backup_vault.aws_backup_vault.name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "default",
  "Statement": [
    {
      "Sid": "Allow: ${data.aws_caller_identity.current.account_id} to copy into aws_backup_vault backup vault",
      "Effect": "Allow",
      "Action": "backup:CopyIntoBackupVault",
      "Resource": "*",
      "Principal": {
        "AWS": "arn:aws:iam:::${data.aws_caller_identity.current.account_id}:root"
      }
    }
  ]
}
POLICY
}
