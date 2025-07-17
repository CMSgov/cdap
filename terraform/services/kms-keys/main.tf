module "standards" {
  source      = "../../modules/standards"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/kms-keys"
  service     = "kms-keys"
}

locals {
  env                              = module.standards.env
  app                              = module.standards.app
  account_id                       = module.standards.account_id
  kms_default_deletion_window_days = 30
  key_alias                        = "alias/${local.app}-${local.env}"
}

data "aws_iam_policy_document" "default_kms_key_policy" {
  statement {
    sid    = "AllowKeyManagement"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "primary" {
  bypass_policy_lockout_safety_check = false
  deletion_window_in_days            = local.kms_default_deletion_window_days
  description                        = "Primary ${local.app} ${local.env} CMK"
  enable_key_rotation                = true
  is_enabled                         = true
  multi_region                       = false
  policy                             = data.aws_iam_policy_document.default_kms_key_policy.json
  rotation_period_in_days            = 365

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "primary" {
  name          = local.key_alias
  target_key_id = aws_kms_key.primary.id
}

resource "aws_kms_key" "secondary" {
  provider                           = aws.secondary
  bypass_policy_lockout_safety_check = false
  deletion_window_in_days            = local.kms_default_deletion_window_days
  description                        = "Secondary ${local.app} ${local.env} CMK"
  enable_key_rotation                = true
  is_enabled                         = true
  multi_region                       = false
  policy                             = data.aws_iam_policy_document.default_kms_key_policy.json
  rotation_period_in_days            = 365

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "secondary" {
  provider      = aws.secondary
  name          = local.key_alias
  target_key_id = aws_kms_key.secondary.id
}
