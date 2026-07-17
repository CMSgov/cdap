resource "datadog_monitor" "custom" {
  for_each = { for m in var.custom_monitors : m.name => m if m.create }

  name    = each.value.name
  type    = each.value.type
  message = "${each.value.message} ${local.notify}"

  query = each.value.query

  monitor_thresholds {
    critical = each.value.thresholds.critical
    warning  = each.value.thresholds.warning # null = omitted by Datadog provider
  }

  notify_no_data      = var.monitor_config.shadow_mode ? false : each.value.notify_no_data
  no_data_timeframe   = each.value.notify_no_data ? each.value.no_data_timeframe_minutes : null
  require_full_window = each.value.require_full_window

  tags = concat(local.base_tags, each.value.tags)
}
