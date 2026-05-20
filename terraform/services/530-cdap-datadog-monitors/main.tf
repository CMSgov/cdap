locals {
  defaults   = yamldecode(file("config/defaults.yml"))
  env_config = yamldecode(file("config/${var.env}.yml"))

  # handle scalars directly with env overwriting default
  shadow_mode = lookup(local.env_config, "shadow_mode", local.defaults.shadow_mode)

  # merge map-typed keys
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

# Default monitors
module "common_datadog_monitors" {
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

# Codebuild-projects specific monitors:

locals {
  codebuild_repos = ["ab2d",
    "ab2d-website",
    "bcda-app",
    "bcda-ssas-app",
    "bcda-static-site",
    "cdap",
    "dpc-app",
    "dpc-ops",
    "dpc-static-site",
  ]
}

resource "datadog_monitor" "codebuild_failed_builds" {
  for_each = toset(local.codebuild_repos)

  name    = "[${upper(module.platform.account_env_suffix)}] [${each.key}]  CodeBuild — Failed Builds"
  type    = "metric alert"
  message = "CodeBuild project ${each.key}-${module.platform.account_env_suffix} has failing builds. ${local.notify}"

  query = "sum(last_30m):sum:aws.codebuild.failed_builds{projectname:${each.key}-${module.platform.account_env_suffix}}> 1"

  monitor_thresholds {
    critical = 1
  }

  tags = [
    "app:${each.key}",
    "environment:${var.env}",
    "managed-by:tofu",
  ]
}

resource "datadog_monitor" "codebuild_queue_backup" {
  for_each = toset(local.codebuild_repos)

  name    = "[${upper(module.platform.account_env_suffix)}] [${each.key}] CodeBuild — Builds Backing Up in Queue"
  type    = "metric alert"
  message = "CodeBuild project ${each.key}-${module.platform.account_env_suffix} builds are queuing — runners may be unavailable. ${local.notify}"

  query = "avg(last_10m):avg:aws.codebuild.queued_duration{projectname:${each.key}-${module.platform.account_env_suffix}} > 120"

  monitor_thresholds {
    critical = 120
    warning  = 72
  }

  tags = [
    "app:${each.key}",
    "environment:${var.env}",
    "managed-by:tofu",
  ]
}
