resource "datadog_monitor" "ecs_cpu_high" {
  count   = var.monitor_config.enabled.ecs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] ECS — CPU Utilization High"
  type    = "metric alert"
  message = "ECS service {{servicename.name}} CPU utilization is critically high. ${local.notify}"

  query = "avg(${var.monitor_config.ecs.timeframe}):avg:aws.ecs.service.cpuutilization{application:${var.app},environment:${var.env}} by {servicename} > ${var.monitor_config.ecs.cpu_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.ecs.cpu_threshold
    warning  = floor(var.monitor_config.ecs.cpu_threshold * 0.85)
  }

  on_missing_data = var.monitor_config.ecs.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "ecs_memory_high" {
  count   = var.monitor_config.enabled.ecs ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] ECS — Memory Utilization High"
  type    = "metric alert"
  message = "ECS service {{servicename.name}} memory utilization is critically high. ${local.notify}"

  query = "avg(${var.monitor_config.ecs.timeframe}):avg:aws.ecs.service.memory_utilization{application:${var.app},environment:${var.env}} by {servicename} > ${var.monitor_config.ecs.memory_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.ecs.memory_threshold
    warning  = floor(var.monitor_config.ecs.memory_threshold * 0.85)
  }

  on_missing_data = var.monitor_config.ecs.on_missing_data

  tags = local.base_tags
}
