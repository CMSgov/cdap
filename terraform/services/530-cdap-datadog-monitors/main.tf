locals {
  defaults   = yamldecode(file("config/defaults.yml"))
  env_config = yamldecode(file("config/${var.env}.yml"))

  # Scalars handled directly — env overrides default
  shadow_mode = lookup(local.env_config, "shadow_mode", local.defaults.shadow_mode)

  # Only merge map-typed keys
  monitor_config = merge(
    { for key in keys(local.defaults) : key => merge(
      lookup(local.defaults, key, {}),
      lookup(local.env_config, key, {})
      ) if can(keys(local.defaults[key])) # only process map-typed keys
    },
    { shadow_mode = local.shadow_mode }
  )

  notify = join(" ", concat(
    local.defaults.notifications.channels,
    try(local.env_config.notifications.channels, [])
  ))
}

module "datadog_monitors" {
  source = "../../modules/datadog_monitors"

  app            = var.app
  env            = var.env
  monitor_config = local.monitor_config
  notify         = local.notify
}

module "platform" {
  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = var.env
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/cdap/${var.env}/datadog/cicd/" }
}
