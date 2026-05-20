locals {
  # Load all config files
  defaults      = yamldecode(file("config/defaults.yml"))
  shared_config = yamldecode(file("config/shared.${var.env}.yml"))

  raw_app_configs = {
    for app in var.apps_served :
    app => merge(
      fileexists("config/${app}.yml")
        ? yamldecode(file("config/${app}.yml"))
        : {},
      fileexists("config/${app}.${var.env}.yml")
        ? yamldecode(file("config/${app}.${var.env}.yml"))
        : {}
    )
  }

  # Merge config per app
  monitor_configs = {
    for app in var.apps_served :
    app => {
      for key in distinct(concat(
        keys(local.defaults),
        keys(local.shared_config),
        keys(local.raw_app_configs[app])
      )) :
      key => merge(
        lookup(local.defaults, key, {}),
        lookup(local.shared_config, key, {}),
        lookup(local.raw_app_configs[app], key, {})
      )
    }
  }

  # Construct notify string per app
  notify_strings = {
    for app in var.apps_served :
    app => join(" ", concat(
      local.defaults.notifications.channels,
      try(local.raw_app_configs[app].notifications.channels, [])
    ))
  }
}

module "datadog_monitors" {
  source   = "../../modules/datadog_monitors"
  for_each = toset(var.apps_served)

  app            = each.key
  env            = var.env
  monitor_config = local.monitor_configs[each.key]
  notify         = local.notify_strings[each.key]
}
