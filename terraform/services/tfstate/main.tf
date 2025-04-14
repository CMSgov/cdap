locals {
  name = "${var.app}-${var.env}-tfstate"
}

module "tfstate_bucket" {
  source = "../../modules/bucket"
  name   = local.name
  legacy = var.legacy
}

