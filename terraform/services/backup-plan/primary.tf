# Secondary Region Resources
data "aws_caller_identity" "current" {}



# resource "aws_iam_role" "primary_kms_admin_role" {
#   name = "KMSAdminRole"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "backup.amazonaws.com"
#         }
#       },
#     ]
#   })
# }

resource "aws_kms_key_policy" "primary_backup_key_policy" {
  key_id = data.aws_kms_key.primary_kms_key.key_id

  policy = jsonencode({
    Id = "primary_backup_key_policy"
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
        "Resource" : "*"
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

data "aws_kms_alias" "primary_kms_alias" {
  name = "alias/bcda-${var.env}"
}

data "aws_kms_key" "primary_kms_key" {
  key_id = data.aws_kms_alias.primary_kms_alias.target_key_id
}

resource "aws_backup_vault" "primary_backup_vault" {
  name        = var.vault_name
  kms_key_arn = data.aws_kms_key.primary_kms_key.arn
}

data "aws_iam_policy_document" "primary_backup_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    actions = [
      "backup:CopyIntoBackupVault",
    ]

    resources = [aws_backup_vault.primary_backup_vault.arn]
  }
}

resource "aws_backup_vault_policy" "primary_backup_vault_policy" {
  backup_vault_name = aws_backup_vault.primary_backup_vault.name
  policy            = data.aws_iam_policy_document.primary_backup_policy.json
}

resource "aws_backup_plan" "aws_backup_plan" {
  name = "backup_plan"
  #TODO only the 4hr rule should be copied to secondary
  rule {
    rule_name         = "backup_rule"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 5 ? * * *)"
    start_window      = 480
    completion_window = 10080
    copy_action {
      destination_vault_arn = aws_backup_vault.secondary_backup_vault.arn
    }

    lifecycle {
      delete_after = 90
    }
  }
  depends_on = [
    aws_backup_vault.secondary_backup_vault
  ]
}

# resource "aws_backup_selection" "aws_backup_selection" {
#   iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSBackupDefaultServiceRole"
#   name         = "backup_selection"
#   plan_id      = aws_backup_plan.aws_backup_plan.id
#   #TODO how to identify resources to be backed up.  Cluster or individual databases?
#   resources    = ""
# }