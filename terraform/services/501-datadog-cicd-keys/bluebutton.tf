locals {
  # CDAP test will manage keys for bluebutton's test, dev
  # CDAP prod will manage keys for bluebutton's prod, sandbox
  bluebutton_env_labels = var.app == "cdap" ? (
    var.env == "test" ? toset(["test", "dev"]) : toset(["prod", "sandbox"])
  ) : toset([])
}

#----------------------
### Application KEY ###
#----------------------
module "datadog_bluebutton_application_key" {
  for_each = local.bluebutton_env_labels
  source   = "../../modules/datadog_application_key"
  app      = "bluebutton"
  env      = each.key

  api_key_manager    = local.resolved_permissions.api_key_manager
  dashboard_manager  = local.resolved_permissions.dashboard_manager
  monitors_manager   = local.resolved_permissions.monitors_manager
  users_manager      = local.resolved_permissions.users_manager
  org_config_manager = local.resolved_permissions.org_config_manager
}

resource "aws_ram_resource_share" "datadog_bluebutton_application_key" {
  for_each                  = local.bluebutton_env_labels
  name                      = "${var.app}-bluebutton-datadog-application-key-${each.key}"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "datadog_bluebutton_application_key" {
  for_each           = local.bluebutton_env_labels
  resource_arn       = module.datadog_bluebutton_application_key[each.key].datadog_application_key.arn
  resource_share_arn = aws_ram_resource_share.datadog_bluebutton_application_key[each.key].arn
}

resource "aws_ram_principal_association" "principal_share_application_key" {
  for_each           = local.bluebutton_env_labels
  principal          = module.standards.ssm.bluebutton_private.value
  resource_share_arn = aws_ram_resource_share.datadog_bluebutton_application_key[each.key].arn
}

#--------------
### API KEY ###
#--------------
module "datadog_bluebutton_api_key" {
  for_each = local.bluebutton_env_labels
  source   = "../../modules/datadog_api_key"
  app      = "bluebutton"
  env      = each.key
  used_for = "cicd"
}

resource "aws_ram_resource_share" "datadog_bluebutton_api_key" {
  for_each                  = local.bluebutton_env_labels
  name                      = "${var.app}-bluebutton-datadog-api-key-${each.key}"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "datadog_bluebutton_api_key" {
  for_each           = local.bluebutton_env_labels
  resource_arn       = module.datadog_bluebutton_api_key[each.key].datadog_api_key.arn
  resource_share_arn = aws_ram_resource_share.datadog_bluebutton_api_key[each.key].arn
}

resource "aws_ram_principal_association" "principal_share_api_key" {
  for_each           = local.bluebutton_env_labels
  principal          = module.standards.ssm.bluebutton_private.value
  resource_share_arn = aws_ram_resource_share.datadog_bluebutton_api_key[each.key].arn
}
