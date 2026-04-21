locals {
  api_key_manager   = var.api_key_manager ? ["api_keys_read", "api_keys_write", "api_keys_delete"] : []
  dashboard_manager = var.dashboard_manager ? ["dashboards_read", "dashboards_write", "dashboards_delete"] : []
  monitors_manager  = var.monitors_manager ? ["monitors_read", "monitors_write", "monitors_downtime"] : []
  users_manager     = var.users_manager ? ["user_access_manage", "user_access_read", "teams_manage"] : []

  application_key_permissions = concat(
    local.api_key_manager,
    local.dashboard_manager,
    local.monitors_manager,
    local.users_manager
  )
}

resource "datadog_application_key" "this" {
  name   = "${var.app}-${var.env}-cicd"
  scopes = local.application_key_permissions
}

data "aws_kms_alias" "primary" {
  name = "alias/${var.app}-${var.env}"
}

resource "aws_ssm_parameter" "datadog_application_key" {
  name        = "/${var.app}/${var.env}/datadog/cicd/application_key"
  description = "Managed by CDAP. Application key for ${var.app} in ${var.env} to leverage infrastructure as code."
  tier        = "Intelligent-Tiering"
  value       = datadog_application_key.this.key
  type        = "SecureString"
  key_id      = data.aws_kms_alias.primary.id
}
