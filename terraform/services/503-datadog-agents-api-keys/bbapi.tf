locals {
  # CDAP test will manage keys for bbapi's test, dev
  # CDAP prod will manage keys for bbapi's prod, sandbox
  bbapi_env_labels = var.app == "cdap" ? (
    var.env == "test" ? toset(["test", "dev"]) : toset(["prod", "sandbox"])
  ) : toset([])
}

# NOTICE: This requires the pre-creation of a KMS keys and permissions for cross-account use
# bbapi will also have to create a ram share acceptance in their AWS account per resource made

#--------------
### API KEY ###
#--------------
module "datadog_bbapi_api_key" {
  for_each = local.bbapi_env_labels
  source   = "../../modules/datadog_api_key"
  app      = "bbapi"
  env      = each.key
  used_for = "agents"
}

resource "aws_ram_resource_share" "datadog_bbapi_api_key" {
  for_each                  = local.bbapi_env_labels
  name                      = "${var.app}-bbapi-${each.key}-datadog-agents-api-key"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "datadog_bbapi_api_key" {
  for_each           = local.bbapi_env_labels
  resource_arn       = module.datadog_bbapi_api_key[each.key].datadog_api_key.arn
  resource_share_arn = aws_ram_resource_share.datadog_bbapi_api_key[each.key].arn
}

resource "aws_ram_principal_association" "principal_share_api_key" {
  for_each           = local.bbapi_env_labels
  principal          = module.standards.ssm.bbapi_private.value
  resource_share_arn = aws_ram_resource_share.datadog_bbapi_api_key[each.key].arn
}
