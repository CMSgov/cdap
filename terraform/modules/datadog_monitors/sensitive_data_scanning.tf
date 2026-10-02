resource "datadog_monitor" "sensitive_data_apm" {
  name    = "[${upper(var.env)}] [${var.app}] APM — Possible Sensitive Data Detected"
  type    = "trace-analytics alert"
  message = "The sensitive data scanner detected a possible leak. ${local.notify}"

  query = <<-EOT
  trace-analytics("sensitive_data:* application:${var.app}").index("trace-search", "djm-search").rollup("count").last("5m") > 0
  EOT

  monitor_thresholds {
    critical = 0
  }

  on_missing_data     = "default"
  require_full_window = false

  tags         = local.base_tags
  draft_status = var.monitor_config.draft_status

  priority = 2
}

resource "datadog_monitor" "sensitive_data_rum" {
  name    = "[${upper(var.env)}] [${var.app}] RUM — Possible Sensitive Data Detected"
  type    = "rum alert"
  message = "The sensitive data scanner detected a possible leak. ${local.notify}"

  query = <<-EOT
  rum("@type:session sensitive_data:* application:${var.app}").rollup("count").last("5m") > 0
  EOT

  monitor_thresholds {
    critical = 0
  }

  on_missing_data     = "default"
  require_full_window = false

  tags         = local.base_tags
  draft_status = var.monitor_config.draft_status

  priority = 2
}
