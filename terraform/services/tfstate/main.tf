locals {
  name = "${var.app}-${var.env}-tfstate"
}

module "tfstate_bucket" {
  source = "../../modules/bucket"
  name   = local.name

  app = var.app
  env = var.env
}
