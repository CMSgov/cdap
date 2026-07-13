locals {
  config = yamldecode(file("${path.module}/config/${var.env}.yml"))
}

# basic repo with versioning
module "repo" {
  for_each = toset(local.config.services)
  source   = "../../modules/ecr_repo"

  platform = module.platform
  service  = each.value
}

# Advanced repo, tagged with release + temp tag classes in a single repo
module "repo_release_pipeline" {
  source = "../../modules/ecr_repo"

  platform = module.platform
  service  = "release-pipeline"

  tag_rules = [
    {
      tag_prefix      = "r"
      retained_images = 3
      description     = "Keep last 3 release images"
    },
    {
      tag_prefix      = "temp-"
      retained_images = 3
      description     = "Keep last 3 temp images"
    }
  ]

  untagged_expiry_days = 30
}
