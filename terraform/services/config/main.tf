module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=0bd3eeae6b03cc8883b7dbdee5f04deb33468260"
  providers   = { aws = aws, aws.secondary = aws.secondary }
  app         = "cdap"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/config"
  service     = local.service
}

locals {
  default_tags = module.standards.default_tags
  service      = "config"
}

module "sops" {
  source = "github.com/CMSgov/cdap//terraform/modules/sops?ref=8874310"

  platform = {
    app               = module.standards.app
    parent_env        = module.standards.env
    env               = module.standards.env
    kms_alias_primary = { id = "cdap-${var.env}" }
    service           = local.service
    is_ephemeral_env  = contains(["sandbox, prod"], var.env) ? true : false
  }
  create_local_sops_wrapper = var.create_local_sops_wrapper
}

output "edit" {
  value = module.sops.sopsw
}
