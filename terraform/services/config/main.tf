module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=9389a80e100ec6cbdf0e2fc25123678c9156ff73"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/terraform/services/config"
  service     = local.service
}

locals {
  default_tags = module.platform.default_tags
  service      = "config"
}

module "sops" {
  source = "github.com/CMSgov/cdap//terraform/modules/sops?ref=8874310"

  platform                  = module.platform
  create_local_sops_wrapper = var.create_local_sops_wrapper
}

output "edit" {
  value = module.sops.sopsw
}
