locals {
  config = yamldecode(file("${path.module}/config/${var.env}.yml"))
}

module "repo" {
  for_each = toset(local.config.services)
  source   = "../../modules/ecr_repo"

  platform                 = module.platform
  service                  = each.value
  default_retained_images  = try(local.config.default_retained_images, 3)
  untagged_images_retained = try(local.config.untagged_images_retained, 10)
}
