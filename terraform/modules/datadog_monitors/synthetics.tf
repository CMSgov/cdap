resource "datadog_monitor" "synthetics_test_failed" {
  for_each = var.monitor_config.enabled.synthetics ? { for t in var.synthetics_tests : t.name => t } : {}

  name    = "[${upper(var.env)}] [${var.app}] Synthetics — ${each.key} Failed"
  type    = "metric alert"
  message = "Synthetic test ${each.key} has failed. ${local.notify}"
  query   = "sum(${var.monitor_config.synthetics.timeframe}):sum:datadog.synthetics.test_runs{result:failed,public_id:${each.value.public_id}}.as_count() > ${var.monitor_config.synthetics.threshold}"

  monitor_thresholds {
    critical = var.monitor_config.synthetics.threshold
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.synthetics.notify_no_data
  no_data_timeframe = var.monitor_config.synthetics.no_data_timeframe_minutes

  tags = local.base_tags
}
