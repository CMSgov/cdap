locals {
  config_file_path = "${path.module}/config/${var.env}/${var.app}.yml"
  config_data      = fileexists(local.config_file_path) ? yamldecode(file(local.config_file_path)) : null

  key_permissions = try(local.config_data["key_permissions"], {})

  default_permissions = {
    api_key_manager          = false
    dashboard_manager        = true
    monitors_manager         = true
    synthetics_manager       = true
    users_manager            = false
    org_config_manager       = false
    private_location_manager = false
  }

  resolved_permissions = {
    for k, v in local.default_permissions :
    k => coalesce(lookup(local.key_permissions, k, null), v)
  }
}

#----------------------
### Application KEY ### Used for CICD, Associated with the admin user whose token is generated in config
#----------------------
module "datadog_application_key" {
  source = "../../modules/datadog_application_key"
  app    = var.app
  env    = var.env

  # permissions can be set per application via a map as needed, this current sets default permissions for all
  api_key_manager          = local.resolved_permissions.api_key_manager
  dashboard_manager        = local.resolved_permissions.dashboard_manager
  monitors_manager         = local.resolved_permissions.monitors_manager
  synthetics_manager       = local.resolved_permissions.synthetics_manager
  users_manager            = local.resolved_permissions.users_manager
  org_config_manager       = local.resolved_permissions.org_config_manager
  private_location_manager = local.resolved_permissions.private_location_manager
}

#--------------
### API KEY ### Used for CICD, Associated with the organization
#--------------
module "datadog_api_key" {
  source   = "../../modules/datadog_api_key"
  app      = var.app
  env      = var.env
  used_for = "cicd"
}
