locals {
  api_key_manager   = var.manage_api_keys ? ["api_keys_read", "api_keys_write"] : []
  dashboard_manager = var.manage_dashboards ? ["dashboards_read", "dashboards_write"] : []
  monitors_manager  = var.manage_monitors ? ["monitors_read", "monitors_write", "monitors_downtime"] : []

  users_manager = var.manage_users ? ["user_access_manage", "user_access_read", "teams_manage"] : []

  application_key_permissions = concat(
    var.api_key_manager,
    var.dashboard_manager,
    var.monitors_manager,
    var.users_manager
  )
}

resource "datadog_application_key" "monitor_management_key" {
  name   = "${var.app}-${var.account_env_suffix}-datadog-cicd"
  scopes = local.application_key_permissions
}
