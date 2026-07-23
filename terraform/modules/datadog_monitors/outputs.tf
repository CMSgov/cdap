output "notify" {
  description = "Notify string used in monitors from this module."
  value       = local.notify
}

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
      http_response_4xx = length(datadog_monitor.s3_http_response_4xx) > 0 ? datadog_monitor.s3_http_response_4xx[0].id : null
      http_response_5xx = length(datadog_monitor.s3_http_response_5xx) > 0 ? datadog_monitor.s3_http_response_5xx[0].id : null
    }
    rds = {
      cpu_high            = length(datadog_monitor.rds_cpu_high) > 0 ? datadog_monitor.rds_cpu_high[0].id : null
      freeable_memory_low = length(datadog_monitor.rds_freeable_memory_low) > 0 ? datadog_monitor.rds_freeable_memory_low[0].id : null
      db_connections_high = length(datadog_monitor.rds_db_connections_high) > 0 ? datadog_monitor.rds_db_connections_high[0].id : null
      replica_lag_high    = length(datadog_monitor.rds_replica_lag_high) > 0 ? datadog_monitor.rds_replica_lag_high[0].id : null
      deadlocks           = length(datadog_monitor.rds_deadlocks) > 0 ? datadog_monitor.rds_deadlocks[0].id : null
    }
  }
}
