resource "datadog_monitor" "watchdog_alerts" {
  count   = var.monitor_config.enabled.watchdog ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Watchdog — Alert"
  type    = "event-v2 alert"
  message = "Watchdog reported an alert for service {{service.name}}."

  query = <<-EOT
  events("source:watchdog tags:\"service:${var.app}\" env:${var.env}").rollup("count").by("story_key").last("30m") > 0
  EOT

  monitor_thresholds {
    critical = 0
  }

  on_missing_data = "default"

  tags         = local.base_tags
  draft_status = var.monitor_config.draft_status
}
