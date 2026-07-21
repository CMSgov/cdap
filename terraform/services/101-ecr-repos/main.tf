locals {
  app_configs = {
    for f in fileset("${path.module}/config", "*/*.yml") :
    (dirname(f) == "cdap" ? "cdap" : trimsuffix(f, ".yml")) => {
      app    = dirname(f)
      env    = trimsuffix(basename(f), ".yml")
      config = try(coalesce(yamldecode(file("${path.module}/config/${f}")), {}), {})
    }
    if trimsuffix(basename(f), ".yml") == var.env
  }

  all_repos = {
    for pair in flatten([
      for config_key, config_data in local.app_configs : [
        for svc in try(config_data.config.services, []) : {
          key     = "${config_data.app}/${svc}"
          app     = config_data.app
          service = svc
        }
      ]
    ]) : pair.key => pair
  }
}

# One platform module per app — each has its own KMS key
module "platform" {
  for_each = local.app_configs

  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = each.value.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}

# One ECR repo per service, using the correct platform instance for its app
module "ecr_repo" {
  for_each = local.all_repos

  source   = "../../modules/ecr_repo"
  platform = module.platform[each.value.app]
  service  = each.value.service
}
