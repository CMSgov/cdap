resource "datadog_monitor" "sns_failed_notifications" {
  count   = var.monitor_config.enabled.sns ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] SNS — Failed Notifications"
  type    = "metric alert"
  message = "SNS topic {{topicname.name}} is experiencing failed notification deliveries. ${local.notify}"

  query = "sum(${var.monitor_config.sns.timeframe}):sum:aws.sns.number_of_notifications_failed{application:${var.app},environment:${var.env}} by {topicname} > ${var.monitor_config.sns.failed_notification_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.sns.failed_notification_threshold
    warning  = floor(var.monitor_config.sns.failed_notification_threshold * 0.5)
  }

  on_missing_data = var.monitor_config.sns.on_missing_data

  tags = local.base_tags
}
