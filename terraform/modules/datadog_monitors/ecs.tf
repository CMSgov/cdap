resource "datadog_monitor" "ecs_cpu_high" {
  count   = var.monitor_config.enabled.ecs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] ECS — CPU Utilization High"
  type    = "metric alert"
  message = "ECS service {{servicename.name}} CPU utilization is critically high. ${var.notify}"

  query = "avg(last_10m):avg:aws.ecs.service.cpuutilization{application:${var.app},environment:${var.env}} by {servicename} > ${var.monitor_config.ecs.cpu_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.ecs.cpu_threshold
    warning  = floor(var.monitor_config.ecs.cpu_threshold * 0.85)
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.ecs.notify_no_data
  no_data_timeframe = var.monitor_config.ecs.no_data_timeframe_minutes

  tags = local.base_tags
}

resource "datadog_monitor" "ecs_memory_high" {
  count   = var.monitor_config.enabled.ecs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] ECS — Memory Utilization High"
  type    = "metric alert"
  message = "ECS service {{servicename.name}} memory utilization is critically high. ${var.notify}"

  query = "avg(last_10m):avg:aws.ecs.service.memory_utilization{application:${var.app},environment:${var.env}} by {servicename} > ${var.monitor_config.ecs.memory_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.ecs.memory_threshold
    warning  = floor(var.monitor_config.ecs.memory_threshold * 0.85)
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.ecs.notify_no_data
  no_data_timeframe = var.monitor_config.ecs.no_data_timeframe_minutes

  tags = local.base_tags
}
