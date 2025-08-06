terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.55"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Set the regional settings
resource "aws_backup_region_settings" "settings" {
  resource_type_opt_in_preference = {
    "Aurora"          = true
    "RDS"             = false
  }

  # Enable features for aurora backups
  resource_type_management_preference = {
    "Aurora" = true
  }
}

# cdap backup vault encryption
resource "aws_kms_key" "cdap_vault" {
  description         = "Encrypt cms aurora data"
  policy              = data.aws_iam_policy_document.cdap_vault_key_policy.json
  enable_key_rotation = true
}

resource "aws_kms_alias" "cdap_vault" {
  name          = "alias/backup_vault_cdap"
  target_key_id = aws_kms_key.cdap_vault.id
}

resource "aws_backup_vault" "cdap" {
  name        = "cdap"
  kms_key_arn = aws_kms_key.cdap_vault.arn
}

resource "aws_backup_vault_policy" "cdap" {
  backup_vault_name = aws_backup_vault.cdap.name

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Allow consumer to copy into cdap backup account",
            "Effect": "Allow",
            "Action": "backup:CopyIntoBackupVault",
            "Resource": "*",
            "Principal": "*",
            "Condition": {
                "StringEquals": {
                    "aws:PrincipalOrgID": [
                        "${data.aws_organizations_organization.current.id}"
                    ]
                }
            }
        }
    ]
}
POLICY
}

resource "aws_backup_plan" "aurora_backup_plan" {
  name = "aurora-daily-backup-plan"

  rule {
    rule_name         = "aurora-daily-rule"
    target_vault_name = aws_backup_vault.cdap.name
    schedule          = "cron(0 5 ? * * *)" # Daily at 5 AM UTC
    lifecycle {
      cold_storage_after = 30 # Transition to cold storage after 30 days
      delete_after       = 90 # Delete after 90 days
    }
    enable_continuous_backup = true # Enables continuous backup for point-in-time recovery
  }
}