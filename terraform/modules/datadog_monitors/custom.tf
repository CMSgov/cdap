resource "datadog_monitor" "custom" {
  for_each = { for m in var.custom_monitors : m.name => m if m.create }

  name    = each.value.name
  type    = each.value.type
  message = "${each.value.message} ${local.notify}"

  draft_status = each.value.draft_status

  query = each.value.query

  monitor_thresholds {
    critical = each.value.thresholds.critical
    warning  = each.value.thresholds.warning # null = omitted by Datadog provider
  }

  on_missing_data = each.value.on_missing_data

  require_full_window = each.value.require_full_window

  tags = concat(local.base_tags, each.value.tags)
}
