locals {
  app  = var.app
  env  = var.env
  name = "${local.app}-${local.env}-tfstate"
}

module "standards" {
  source = "../../modules/standards" #TODO: Update with appropriate reference

  app         = local.app
  env         = local.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tfstate"
  service     = "tfstate"
  providers   = { aws = aws, aws.secondary = aws.secondary }
}

module "tfstate_bucket" {
  source = "../../modules/bucket" #TODO: Update with appropriate reference
  name   = local.name

  app = local.app
  env = local.env
}
