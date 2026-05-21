locals {
  # CDAP test will manage keys for bb's test, dev
  # CDAP prod will manage keys for bb's prod, sandbox
  bb_env_labels = var.app == "cdap" ? (
    var.env == "test" ? toset(["test", "dev"]) : toset(["prod", "sandbox"])
  ) : toset([])
}

# NOTICE: This requires the pre-creation of a KMS keys and permissions for cross-account use
# bb will also have to create a ram share acceptance in their AWS account per resource made

#--------------
### API KEY ###
#--------------
module "datadog_bb_api_key" {
  for_each = local.bb_env_labels
  source   = "../../modules/datadog_api_key"
  app      = "bb"
  env      = each.key
  used_for = "agents"
}

resource "aws_ram_resource_share" "datadog_bb_api_key" {
  for_each                  = local.bb_env_labels
  name                      = "${var.app}-bb-${each.key}-datadog-agents-api-key"
  allow_external_principals = true
}

resource "aws_ram_resource_association" "datadog_bb_api_key" {
  for_each           = local.bb_env_labels
  resource_arn       = module.datadog_bb_api_key[each.key].ssm_parameter.arn
  resource_share_arn = aws_ram_resource_share.datadog_bb_api_key[each.key].arn
}

resource "aws_ram_principal_association" "principal_share_api_key" {
  for_each           = local.bb_env_labels
  principal          = module.standards.ssm.bb_aws_account_id.value
  resource_share_arn = aws_ram_resource_share.datadog_bb_api_key[each.key].arn
}
