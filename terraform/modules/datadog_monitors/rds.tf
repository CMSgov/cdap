resource "datadog_monitor" "rds_cpu_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — CPU Utilization High"
  type    = "metric alert"
  message = "Aurora cluster {{dbclusteridentifier.name}} CPU utilization is critically high. ${local.notify}"

  query = "avg(${var.monitor_config.rds.timeframe}):avg:aws.rds.cpuutilization{application:${var.app},environment:${var.env}} by {dbclusteridentifier} > ${var.monitor_config.rds.cpu_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.cpu_threshold
    warning  = floor(var.monitor_config.rds.cpu_threshold * 0.85)
  }

  on_missing_data = var.monitor_config.rds.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "rds_freeable_memory_low" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Freeable Memory Low"
  type    = "metric alert"
  message = "Aurora cluster {{dbclusteridentifier.name}} is running low on freeable memory. ${local.notify}"

  query = "avg(${var.monitor_config.rds.timeframe}):avg:aws.rds.freeable_memory{application:${var.app},environment:${var.env}} by {dbclusteridentifier} < ${var.monitor_config.rds.freeable_memory_threshold_mb * 1000000}"

  monitor_thresholds {
    critical = var.monitor_config.rds.freeable_memory_threshold_mb * 1000000 # Reported in bytes
    warning  = var.monitor_config.rds.freeable_memory_threshold_mb * 1000000 * 2
  }

  on_missing_data = var.monitor_config.rds.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "rds_db_connections_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — DB Connections High"
  type    = "metric alert"
  message = "Aurora instance {{dbinstanceidentifier.name}} is approaching its max connection limit. ${local.notify}"

  query = "avg(${var.monitor_config.rds.timeframe}):avg:aws.rds.database_connections{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.db_connections_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.db_connections_threshold
    warning  = floor(var.monitor_config.rds.db_connections_threshold * 0.80)
  }

  on_missing_data = var.monitor_config.rds.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "rds_replica_lag_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Replica Lag High"
  type    = "metric alert"
  message = "Aurora replica {{dbinstanceidentifier.name}} lag is too high — read queries may return stale data. ${local.notify}"

  query = "avg(${var.monitor_config.rds.timeframe}):avg:aws.rds.aurora_replica_lag{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.replica_lag_seconds * 1000}"

  monitor_thresholds {
    critical = var.monitor_config.rds.replica_lag_seconds * 1000 # Becomes milliseconds
    warning  = floor(var.monitor_config.rds.replica_lag_seconds * 1000 * 0.75)
  }

  on_missing_data = var.monitor_config.rds.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "rds_deadlocks" {
  count   = var.monitor_config.enabled.rds && var.monitor_config.rds.deadlocks_enabled ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Deadlocks Detected"
  type    = "metric alert"
  message = "Aurora instance {{dbinstanceidentifier.name}} is experiencing deadlocks. ${local.notify}"

  query = "sum(${var.monitor_config.rds.timeframe}):sum:aws.rds.deadlocks{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.deadlock_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.deadlock_threshold
  }

  on_missing_data = var.monitor_config.rds.on_missing_data

  tags = local.base_tags
}
