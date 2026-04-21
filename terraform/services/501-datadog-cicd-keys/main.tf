locals {
  default_permissions = {
    api_key_manager   = false
    dashboard_manager = true
    monitors_manager  = true
    users_manager     = false
  }

  resolved_permissions = {
    for k, v in local.default_permissions :
    k => (
      lookup(var.app_permissions, "${var.app}-${var.env}", null) != null
      ? coalesce(lookup(var.app_permissions["${var.app}-${var.env}"], k, null), v)
      : v
    )
  }
}

data "aws_ssm_parameter" "datadog_init_api_key" {
  name            = "/dasgapi/sensitive/datadog/init_api_key"
  with_decryption = true
}

data "aws_ssm_parameter" "datadog_init_app_key" {
  name            = "/dasgapi/sensitive/datadog/init_application_key"
  with_decryption = true
}

#----------------------
### Application KEY ### Used for CICD, Associated with the admin user whose token is generated in config
#----------------------
module "datadog_application_key" {
  source = "../../modules/datadog_application_key"
  app    = var.app
  env    = var.env

  # permissions can be set per application via a map as needed, this current sets default permissions for all
  api_key_manager   = local.resolved_permissions.api_key_manager
  dashboard_manager = local.resolved_permissions.dashboard_manager
  monitors_manager  = local.resolved_permissions.monitors_manager
  users_manager     = local.resolved_permissions.users_manager
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

module "standards" {
  source = "../../modules/standards"

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/datadog-agents-api-keys"
  service     = "datadog"
  providers   = { aws = aws, aws.secondary = aws.secondary }
}
