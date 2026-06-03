locals {
  # load the config for the current cdap environment
  env_config = yamldecode(file("${path.module}/config/${var.env}.yml"))

  # evaluate the YAML for each entry
  kms_shares = {
    for entry in flatten([
      for app, cfg in local.env_config.shares : [
        for env in cfg.envs : {
          key                = "${app}-${env}"
          app                = app
          env                = env
          principal_ssm_path = "/cdap/${var.env}/external/${app}/sensitive/${cfg.principal_ssm_key}"
        }
      ]
    ]) : entry.key => entry
  }
}

# Lookup ssm parameters with information about AWS principals that will have access granted
data "aws_ssm_parameter" "principal" {
  for_each = toset([
    for k, v in local.kms_shares : v.principal_ssm_path
  ])
  name = each.key
}

# external account will also have to configure IAM permissions in their account to access this KMS key
#--------------
### KMS KEYS ###
#--------------

resource "aws_kms_key" "shares" {
  for_each                = local.kms_shares
  description             = "KMS key for ${each.value.app} ${each.value.env}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CDAP account: full control delegated to IAM
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${module.standards.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # External account limited to: decrypt via SSM only, even if they set permissive IAM
      {
        Sid    = "AllowExternalDecryptViaSecretsManager"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_ssm_parameter.principal[each.value.principal_ssm_path].value
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${module.standards.primary_region.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    ExternalAppName = each.value.app
    ExternalAppEnv  = each.value.env
  }
}

resource "aws_kms_alias" "shares" {
  for_each      = local.kms_shares
  name          = "alias/${each.value.app}-${each.value.env}"
  target_key_id = aws_kms_key.shares[each.key].key_id
}
