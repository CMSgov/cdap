output "monitor_ids" {
  description = "All Datadog monitor IDs created by this module, grouped by service"
  value = {
    ecs = {
      cpu_high    = length(datadog_monitor.ecs_cpu_high) > 0 ? datadog_monitor.ecs_cpu_high[0].id : null
      memory_high = length(datadog_monitor.ecs_memory_high) > 0 ? datadog_monitor.ecs_memory_high[0].id : null
    }
    sqs = {
      dlq_messages_visible = length(datadog_monitor.sqs_dlq_messages_visible) > 0 ? datadog_monitor.sqs_dlq_messages_visible[0].id : null
      message_age          = length(datadog_monitor.sqs_message_age) > 0 ? datadog_monitor.sqs_message_age[0].id : null
    }
    sns = {
      failed_notifications = length(datadog_monitor.sns_failed_notifications) > 0 ? datadog_monitor.sns_failed_notifications[0].id : null
    }
    lambda = {
      error_rate = length(datadog_monitor.lambda_error_rate) > 0 ? datadog_monitor.lambda_error_rate[0].id : null
      throttles  = length(datadog_monitor.lambda_throttles) > 0 ? datadog_monitor.lambda_throttles[0].id : null
      duration   = length(datadog_monitor.lambda_duration) > 0 ? datadog_monitor.lambda_duration[0].id : null
    }
    s3 = {
      errors_4xx = length(datadog_monitor.s3_4xx_errors) > 0 ? datadog_monitor.s3_4xx_errors[0].id : null
      errors_5xx = length(datadog_monitor.s3_5xx_errors) > 0 ? datadog_monitor.s3_5xx_errors[0].id : null
    }
  }
}
