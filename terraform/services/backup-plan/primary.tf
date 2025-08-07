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
                    "arn:aws:iam::${local.source_account_number}:root",
                    "arn:aws:iam::${local.target_account_number}:root"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${local.kms_admin_role_arn}"
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
                    "arn:aws:iam::${local.source_account_number}:root",
                    "arn:aws:iam::${local.target_account_number}:root",
                    "${local.kms_admin_role_arn}"
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
                    "arn:aws:iam::${local.source_account_number}:root",
                    "arn:aws:iam::${local.target_account_number}:root",
                    "${local.kms_admin_role_arn}"
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
  name        = "aws_backup_vault"
  kms_key_arn = aws_kms_key.aws_kms_key.arn
}

resource "aws_backup_plan" "aws_backup_plan" {
  name = "backup_plan"
#TODO only the 4hr rule should be copied to secondary
  rule {
    rule_name         = "backup_rule"
    target_vault_name = aws_backup_vault.aws_backup_vault.name
    schedule          = "cron(0 5 ? * * *)"
    start_window      = 480
    completion_window = 10080
    copy_action {
      destination_vault_arn = local.destination_vault
    }

    lifecycle {
      delete_after = 90
    }
  }
}

resource "aws_backup_selection" "aws_backup_selection" {
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSBackupDefaultServiceRole"
  name         = "backup_selection"
  plan_id      = aws_backup_plan.aws_backup_plan.id
  #TODO how to identify resources to be backed up.  Cluster or individual databases?
  resources    = ""
}