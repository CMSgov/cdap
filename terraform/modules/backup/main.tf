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
