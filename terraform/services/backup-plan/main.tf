module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=0bd3eeae6b03cc8883b7dbdee5f04deb33468260"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/backup-plan"
  service     = "backup-plan"
  app         = "cdap"
}

data "aws_backup_vault" "primary" {
  name = "CMS_OIT_Backups_Vault"
}

data "aws_backup_vault" "secondary" {
  name     = "CMS_OIT_Backups_Vault"
  provider = aws.secondary
}

resource "aws_backup_plan" "this" {
  name = "4Hours1CA_Daily7_Weekly35_Monthly90"
  #only the 4hr rule should be copied to secondary
  rule {
    rule_name         = "4Hourly_1CA"
    target_vault_name = data.aws_backup_vault.primary.name
    schedule          = "cron(0 */4 * * ? *)"

    copy_action {
      destination_vault_arn = data.aws_backup_vault.secondary.arn
    }

    lifecycle {
      delete_after = 1
    }
  }

  rule {
    rule_name         = "Daily_7"
    target_vault_name = data.aws_backup_vault.primary.name
    schedule          = "cron(0 4 * * ? *)"

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "Weekly_35"
    target_vault_name = data.aws_backup_vault.primary.name
    schedule          = "cron(0 0 ? * SAT *)"

    lifecycle {
      delete_after = 35
    }
  }

  rule {
    rule_name         = "Monthly_90"
    target_vault_name = data.aws_backup_vault.primary.name
    schedule          = "cron(0 0 1 * ? *)"

    lifecycle {
      delete_after = 90
    }
  }

}

resource "aws_backup_selection" "this" {
  # This iam role is the one CMS is using for their backup plan.
  iam_role_arn = "arn:aws:iam::${module.standards.account_id}:role/delegatedadmin/developer/cms-oit-aws-backup-service-role"
  name         = "cdap_managed_backup_selection"
  plan_id      = aws_backup_plan.this.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "AWS_Backup"
    value = "4Hours1CA_Daily7_Weekly35_Monthly90"
  }
}
