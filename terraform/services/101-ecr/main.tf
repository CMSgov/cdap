module "datadog_apm" {
  source = "../../modules/ecr_repo"

  platform = module.platform
  service  = "datadog-apm"
}
