resource "datadog_monitor" "acm_cert_expiry" {
  count   = var.monitor_config.enabled.acm ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] ACM — Certificate Approaching Expiry"
  type    = "metric alert"
  message = "ACM certificate {{domain.name}} is approaching expiration. ${local.notify}"

  query = "avg(${var.monitor_config.acm.timeframe}):avg:aws.acm.days_to_expiry{application:${var.app},environment:${var.env}} by {domain} < ${var.monitor_config.acm.critical_days_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.acm.critical_days_threshold
    warning  = var.monitor_config.acm.warning_days_threshold
  }

  notify_no_data    = var.monitor_config.acm.notify_no_data
  no_data_timeframe = var.monitor_config.acm.no_data_timeframe_minutes

  evaluation_delay = local.aws_evaluation_delay

  tags         = local.base_tags
  draft_status = var.monitor_config.draft_status
}
