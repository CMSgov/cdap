locals {
  # Map of { "bb-test" => { service = "bb", env = "test" }, "bfd-test" => { ... }, ... }
  # See existing examples in config/prod/cdap.yml
  cross_account_shares = {
    for entry in flatten([
      for service, cfg in try(local.config_data["cross_account_shares"], {}) : [
        for env in cfg.env_labels : {
          key     = "${service}-${env}"
          service = service
          env     = env
        }
      ]
    ]) : entry.key => entry
  }
  # lookup the root for the ssm shares in a predictable fashion reflected in SOPS
  shares_ssm_roots = {
    for service in keys(try(local.config_data["cross_account_shares"], {})) :
    "external_${service}" => "/cdap/${var.env}/external/${service}/sensitive/"
  }
}

data "aws_kms_alias" "shares" {
  for_each = local.cross_account_shares
  name     = "alias/${each.value.service}-${each.value.env}"
}

# NOTICE: This requires the pre-creation of a KMS keys and permissions for cross-account use
# bb will also have to create IAM in their AWS account per resource made
#----------------------
### Application KEY ###
#----------------------
module "additional_datadog_application_key" {
  for_each = local.cross_account_shares
  source   = "../../modules/datadog_application_key"
  app      = each.value.service
  env      = each.value.env

  api_key_manager    = local.resolved_permissions.api_key_manager
  dashboard_manager  = local.resolved_permissions.dashboard_manager
  monitors_manager   = local.resolved_permissions.monitors_manager
  users_manager      = local.resolved_permissions.users_manager
  org_config_manager = local.resolved_permissions.org_config_manager
}


resource "aws_secretsmanager_secret" "datadog_application_key" {
  for_each    = local.cross_account_shares
  name        = "${var.app}/${each.value.service}/${each.value.env}/datadog/application-key"
  description = "Datadog application key for ${each.value.service} ${each.value.env} — shared cross-account"
  kms_key_id  = data.aws_kms_alias.shares[each.key].target_key_arn

  tags = {
    Service = each.value.service
    Env     = each.value.env
  }
}

resource "aws_secretsmanager_secret_version" "datadog_application_key" {
  for_each      = local.cross_account_shares
  secret_id     = aws_secretsmanager_secret.datadog_application_key[each.key].id
  secret_string = module.additional_datadog_application_key[each.key].ssm_parameter.value
}

resource "aws_secretsmanager_secret_policy" "datadog_application_key" {
  for_each   = local.cross_account_shares
  secret_arn = aws_secretsmanager_secret.datadog_application_key[each.key].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountRead"
        Effect = "Allow"
        Principal = {
          AWS = module.standards.ssm["external_${each.value.service}"].aws_account_id.value
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

#--------------
### API KEY ###
#--------------
module "additional_datadog_api_key" {
  for_each = local.cross_account_shares
  source   = "../../modules/datadog_api_key"
  app      = each.value.service
  env      = each.value.env
  used_for = "cicd"
}

resource "aws_secretsmanager_secret" "datadog_api_key" {
  for_each    = local.cross_account_shares
  name        = "${var.app}/${each.value.service}/${each.value.env}/datadog/cicd/api-key/"
  description = "Datadog CICD API key for ${each.value.service} ${each.value.env} — shared cross-account"
  kms_key_id  = data.aws_kms_alias.shares[each.key].target_key_arn

  tags = {
    Service = each.value.service
    Env     = each.value.env
  }
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  for_each      = local.cross_account_shares
  secret_id     = aws_secretsmanager_secret.datadog_api_key[each.key].id
  secret_string = module.additional_datadog_api_key[each.key].ssm_parameter.value
}

resource "aws_secretsmanager_secret_policy" "datadog_api_key" {
  for_each   = local.cross_account_shares
  secret_arn = aws_secretsmanager_secret.datadog_api_key[each.key].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountRead"
        Effect = "Allow"
        Principal = {
          AWS = module.standards.ssm["external_${each.value.service}"].aws_account_id.value
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}
