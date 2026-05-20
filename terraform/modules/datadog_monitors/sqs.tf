resource "datadog_monitor" "sqs_dlq_messages_visible" {
  count   = var.monitor_config.enabled.sqs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] SQS — DLQ Messages Visible"
  type    = "metric alert"
  message = "Dead letter queue {{queuename.name}} has visible messages. Investigate immediately. ${var.notify}"

  query = "sum(last_5m):sum:aws.sqs.approximate_number_of_messages_visible{app:${var.app},environment:${var.env},queuename:*dlq*} by {queuename} > ${var.monitor_config.sqs.dlq_message_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.sqs.dlq_message_threshold
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.sqs.notify_no_data
  no_data_timeframe = var.monitor_config.sqs.no_data_timeframe_minutes

  tags = local.base_tags
}

resource "datadog_monitor" "sqs_message_age" {
  count   = var.monitor_config.enabled.sqs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] SQS — Message Age Too High"
  type    = "metric alert"
  message = "Messages in queue {{queuename.name}} are aging beyond the acceptable threshold. ${var.notify}"

  query = "avg(last_10m):avg:aws.sqs.approximate_age_of_oldest_message{app:${var.app},environment:${var.env}} by {queuename} > ${var.monitor_config.sqs.max_message_age_seconds}"

  monitor_thresholds {
    critical = var.monitor_config.sqs.max_message_age_seconds
    warning  = floor(var.monitor_config.sqs.max_message_age_seconds * 0.75)
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.sqs.notify_no_data
  no_data_timeframe = var.monitor_config.sqs.no_data_timeframe_minutes

  tags = local.base_tags
}

