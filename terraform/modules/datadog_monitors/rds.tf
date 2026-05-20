resource "datadog_monitor" "rds_cpu_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — CPU Utilization High"
  type    = "metric alert"
  message = "Aurora cluster {{dbclusteridentifier.name}} CPU utilization is critically high. ${var.notify}"

  query = "avg(last_10m):avg:aws.rds.cpuutilization{application:${var.app},environment:${var.env}} by {dbclusteridentifier} > ${var.monitor_config.rds.cpu_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.cpu_threshold
    warning  = floor(var.monitor_config.rds.cpu_threshold * 0.85)
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.rds.notify_no_data
  no_data_timeframe = var.monitor_config.rds.no_data_timeframe_minutes

  tags = local.base_tags
}

resource "datadog_monitor" "rds_freeable_memory_low" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Freeable Memory Low"
  type    = "metric alert"
  message = "Aurora cluster {{dbclusteridentifier.name}} is running low on freeable memory. ${var.notify}"

  query = "avg(last_10m):avg:aws.rds.freeable_memory{application:${var.app},environment:${var.env}} by {dbclusteridentifier} < ${var.monitor_config.rds.freeable_memory_threshold_mb * 1000000}"

  monitor_thresholds {
    critical = var.monitor_config.rds.freeable_memory_threshold_mb * 1000000 # Reported in bytes
    warning  = var.monitor_config.rds.freeable_memory_threshold_mb * 1000000 * 2
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.rds.notify_no_data
  no_data_timeframe = var.monitor_config.rds.no_data_timeframe_minutes

  tags = local.base_tags
}

resource "datadog_monitor" "rds_db_connections_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — DB Connections High"
  type    = "metric alert"
  message = "Aurora instance {{dbinstanceidentifier.name}} is approaching its max connection limit. ${var.notify}"

  query = "avg(last_10m):avg:aws.rds.database_connections{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.db_connections_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.db_connections_threshold
    warning  = floor(var.monitor_config.rds.db_connections_threshold * 0.80)
  }

  notify_no_data    = var.monitor_config.shadow_mode ? false : var.monitor_config.rds.notify_no_data
  no_data_timeframe = var.monitor_config.rds.no_data_timeframe_minutes

  tags = local.base_tags
}

resource "datadog_monitor" "rds_replica_lag_high" {
  count   = var.monitor_config.enabled.rds ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Replica Lag High"
  type    = "metric alert"
  message = "Aurora replica {{dbinstanceidentifier.name}} lag is too high — read queries may return stale data. ${var.notify}"

  query = "avg(last_5m):avg:aws.rds.aurora_replica_lag{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.replica_lag_seconds * 1000}"

  monitor_thresholds {
    critical = var.monitor_config.rds.replica_lag_seconds * 1000 # Becomes milliseconds
    warning  = floor(var.monitor_config.rds.replica_lag_seconds * 1000 * 0.75)
  }

  tags = local.base_tags
}

resource "datadog_monitor" "rds_deadlocks" {
  count   = var.monitor_config.enabled.rds && var.monitor_config.rds.deadlocks_enabled ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Aurora RDS — Deadlocks Detected"
  type    = "metric alert"
  message = "Aurora instance {{dbinstanceidentifier.name}} is experiencing deadlocks. ${var.notify}"

  query = "sum(last_5m):sum:aws.rds.deadlocks{application:${var.app},environment:${var.env}} by {dbinstanceidentifier} > ${var.monitor_config.rds.deadlock_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.rds.deadlock_threshold
  }

  tags = local.base_tags
}
