locals {
  full_name  = "${var.app}-${var.env}-api-waf-sync"
  db_sg_name = "${var.app}-${var.env}-db"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "api_waf_sync_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Synchronizes the IP whitelist in ${var.app} with the WAF IP Set"

  handler = "bootstrap"
  runtime = "provided.al2"

  function_role_inline_policies = {
    waf-access = data.aws_iam_policy_document.aws_waf_access.json
  }

  schedule_expression = "cron(0/10 * * * ? *)"

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-api-waf-sync"
    DB_HOST  = data.aws_ssm_parameter.dpc_db_host.value
  }
  kms_key_arn = "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alias/${var.app}-${var.env}"
}

# Add a rule to the database security group to allow access from the function
data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_security_group_rule" "function_access" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  description = "api-waf-sync function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.api_waf_sync_function.security_group_id
}

# Because we inline policies, we cannot just link to aws:policy/AWSWAFFullAccess
data "aws_iam_policy_document" "aws_waf_access" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "wafv2:ListIpSets",
      "wafv2:GetIpSet",
      "wafv2:UpdateIpSet",
    ]
  }
}

# db host
data "aws_ssm_parameter" "dpc_db_host" {
  name = "/dpc/${var.env}/db/url"
}
