resource "datadog_monitor" "s3_4xx_errors" {
  count   = var.monitor_config.enabled.s3 ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] S3 — 4xx Error Rate High"
  type    = "metric alert"
  message = "S3 bucket {{bucketname.name}} is returning a high rate of 4xx errors. ${var.notify}"

  query = "sum(last_5m):sum:aws.s3.4xx_errors{app:${var.app},env:${var.env}} by {bucketname} > ${var.monitor_config.s3.error_threshold_4xx}"

  monitor_thresholds {
    critical = var.monitor_config.s3.error_threshold_4xx
    warning  = floor(var.monitor_config.s3.error_threshold_4xx * 0.75)
  }

  tags = local.base_tags
}

resource "datadog_monitor" "s3_5xx_errors" {
  count   = var.monitor_config.enabled.s3 ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] S3 — 5xx Error Rate High"
  type    = "metric alert"
  message = "S3 bucket {{bucketname.name}} is returning 5xx errors — possible AWS-side issue. ${var.notify}"

  query = "sum(last_5m):sum:aws.s3.5xx_errors{app:${var.app},env:${var.env}} by {bucketname} > ${var.monitor_config.s3.error_threshold_5xx}"

  monitor_thresholds {
    critical = var.monitor_config.s3.error_threshold_5xx
    warning  = floor(var.monitor_config.s3.error_threshold_5xx * 0.5)
  }

  tags = local.base_tags
}
