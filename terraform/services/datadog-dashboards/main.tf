locals {
  # Load environment-level config (e.g., prod.yml, dev.yml)
  env_config = yamldecode(file("./config/${var.env}.yml"))

  # Build a map of apps_served: { "dpc" = {}, "cdap" = {}, ... }
  apps_served = toset(local.env_config.apps_served)
  default_enable_widgets = {
    lambda = true
    aurora = true
    sns    = true
    alb    = true
    s3     = true
    ecs    = true
  }

  app_configs = {
    for app in local.apps_served :
    app => try(yamldecode(file("./config/${app}.yml")), {})
  }
  app_env_overrides = {
    for app in local.apps_served :
    app => lookup(
      lookup(local.app_configs[app], "env_overrides", {}),
      var.env,
      {}
    )
  }
}

module "datadog_dashboard" {
  source   = "../../modules/datadog_dashboard"
  for_each = local.apps_served
  app      = each.key
  name_rewrite = lookup(
    local.app_env_overrides[each.key],
    "name_rewrite",
    lookup(local.app_configs[each.key], "name_rewrite", null)
  )

  custom_widgets = lookup(
    local.app_env_overrides[each.key],
    "custom_widgets",
    lookup(local.app_configs[each.key], "custom_widgets", [])
  )

  enable_default_widgets = merge(
    local.default_enable_widgets,
    lookup(local.app_configs[each.key], "enable_default_widgets", {}),
    lookup(local.app_env_overrides[each.key], "enable_default_widgets", {})
  )

}

module "standards" {
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = var.env
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/cdap/${var.env}/datadog/cicd/" }
}
