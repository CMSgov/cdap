resource "aws_backup_vault" "primary_backup_vault" {
  name = "CMS_OIT_Backups_Vault"
  provider = aws.primary
}

resource "aws_backup_vault" "secondary_backup_vault" {
  name = "CMS_OIT_Backups_Vault"
  provider = aws.secondary
}

resource "aws_backup_plan" "aws_backup_plan" {
  provider = aws.primary
  name     = "cdap_managed_backup_plan"
  #only the 4hr rule should be copied to secondary
  rule {
    rule_name         = "4Hourly_1"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 */4 * * ? *)"
    start_window      = 60
    completion_window = 180
    copy_action {
      destination_vault_arn = aws_backup_vault.secondary_backup_vault.arn
    }

    lifecycle {
      delete_after = 1
    }
  }

  rule {
    rule_name         = "Daily_7"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 4 * * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "Weekly_35"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 0 ? * SAT *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 35
    }
  }

  rule {
    rule_name         = "Monthly_90"
    target_vault_name = aws_backup_vault.primary_backup_vault.name
    schedule          = "cron(0 0 1 * ? *)"
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = 90
    }
  }

}

resource "aws_backup_selection" "this" {
  # This iam role is the one CMS is using for their backup plan.
  provider = aws.primary
  iam_role_arn = "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
  name         = "cdap_managed_backup_selection"
  plan_id      = aws_backup_plan.aws_backup_plan.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "AWS_Backup"
    value = "4Hours1_Daily7_Weekly35_Monthly90"
  }
}
