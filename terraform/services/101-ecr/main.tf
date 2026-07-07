module "common_datadog_monitors" {
  source = "../../modules/ecr_repo"

  platform = module.platform
}
