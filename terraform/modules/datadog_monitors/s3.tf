resource "datadog_monitor" "s3_http_response_4xx" {
  count   = var.monitor_config.enabled.s3 ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] S3 — 4xx Error Rate High"
  type    = "metric alert"
  message = "S3 bucket {{bucketname.name}} is returning a high rate of 4xx errors. ${local.notify}"

  query = "sum(${var.monitor_config.s3.timeframe}):sum:aws.s3.4xx_errors{application:${var.app},environment:${var.env}} by {bucketname} > ${var.monitor_config.s3.http_response_4xx_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.s3.http_response_4xx_threshold
    warning  = floor(var.monitor_config.s3.http_response_4xx_threshold * 0.75)
  }

  on_missing_data = var.monitor_config.s3.on_missing_data

  tags = local.base_tags
}

resource "datadog_monitor" "s3_http_response_5xx" {
  count   = var.monitor_config.enabled.s3 ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] S3 — 5xx Error Rate High"
  type    = "metric alert"
  message = "S3 bucket {{bucketname.name}} is returning 5xx errors — possible AWS-side issue. ${local.notify}"

  query = "sum(${var.monitor_config.s3.timeframe}):sum:aws.s3.5xx_errors{application:${var.app},environment:${var.env}} by {bucketname} > ${var.monitor_config.s3.http_response_5xx_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.s3.http_response_5xx_threshold
    warning  = floor(var.monitor_config.s3.http_response_5xx_threshold * 0.5)
  }

  on_missing_data = var.monitor_config.s3.on_missing_data

  tags = local.base_tags
}
