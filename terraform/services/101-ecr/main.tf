locals {
  config = yamldecode(file("${path.module}/config/${var.env}.yml"))
}

module "repo" {
  for_each = toset(local.config.services)
  source   = "../../modules/ecr_repo"

  platform = module.platform
  service  = each.value
}
