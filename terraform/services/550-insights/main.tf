locals {
  insights_config = yamldecode(file("${path.module}/config/${var.env}.yml"))

  insights_exports = {
    for entry in flatten([
      for app, cfg in local.insights_config.insights_exports : [
        for env in cfg.envs : {
          key                   = "${app}-${env}"
          app                   = app
          env                   = env
          bucket_name           = "${app}-${env}-aurora-export"
          internal_role_arn     = "arn:aws:iam::${module.standards.account_id}:role/${app}-${env}-aurora"
          external_account_path = try(cfg.external_writer.account_ssm_path, null) == null ? null : "/cdap/${var.env}/${cfg.external_writer.account_ssm_path}"
          external_role_path    = try(cfg.external_writer.role_ssm_path, null) == null ? null : "/cdap/${var.env}/${cfg.external_writer.role_ssm_path}"
        }
      ]
    ]) : entry.key => entry
  }

  internal_writers = { for k, v in local.insights_exports : k => v if v.external_account_path == null }
  external_writers = { for k, v in local.insights_exports : k => v if v.external_account_path != null }
}

data "aws_ssm_parameter" "dasg_insights_account_id" {
  name = "/cdap/prod/external/dasg_insights/sensitive/aws_account_id"
}

data "aws_ssm_parameter" "external_writer_account" {
  for_each = toset([for k, v in local.external_writers : v.external_account_path])
  name     = each.key
}

data "aws_ssm_parameter" "external_writer_role" {
  for_each = toset([for k, v in local.external_writers : v.external_role_path])
  name     = each.key
}

# Shared KMS key


resource "aws_kms_key" "aurora_export" {
  description             = "Shared KMS key for insights aurora export buckets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.aurora_export_kms.json
}

resource "aws_kms_alias" "aurora_export" {
  name          = "alias/aurora_export"
  target_key_id = aws_kms_key.aurora_export.key_id
}

module "export_buckets" {
  source   = "../../modules/bucket"
  for_each = local.insights_exports

  app                = each.value.app
  env                = each.value.env
  name               = each.value.bucket_name
  kms_key_arn        = aws_kms_alias.aurora_export.target_key_arn
  use_custom_kms_key = true

  additional_bucket_policies = [data.aws_iam_policy_document.export_bucket_access[each.key].json]
}
