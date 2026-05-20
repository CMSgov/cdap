resource "datadog_monitor" "lambda_error_rate" {
  count   = var.monitor_config.enabled.lambda ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Lambda — Error Rate High"
  type    = "metric alert"
  message = "Lambda function {{functionname.name}} has a high error rate. ${var.notify}"

  query = "sum(last_5m):(sum:aws.lambda.errors{app:${var.app},env:${var.env}} by {functionname} / sum:aws.lambda.invocations{app:${var.app},env:${var.env}} by {functionname}) * 100 > ${var.monitor_config.lambda.error_rate_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.lambda.error_rate_threshold
    warning  = floor(var.monitor_config.lambda.error_rate_threshold * 0.75)
  }

  tags = local.base_tags
}

resource "datadog_monitor" "lambda_throttles" {
  count   = var.monitor_config.enabled.lambda ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Lambda — Throttles High"
  type    = "metric alert"
  message = "Lambda function {{functionname.name}} is being throttled. ${var.notify}"

  query = "sum(last_5m):sum:aws.lambda.throttles{app:${var.app},env:${var.env}} by {functionname} > ${var.monitor_config.lambda.throttle_threshold}"

  monitor_thresholds {
    critical = var.monitor_config.lambda.throttle_threshold
    warning  = floor(var.monitor_config.lambda.throttle_threshold * 0.75)
  }

  tags = local.base_tags
}

resource "datadog_monitor" "lambda_duration" {
  count   = var.monitor_config.enabled.lambda ? 1 : 0
  name    = "[${upper(var.env)}] [${var.app}] Lambda — Duration Near Timeout"
  type    = "metric alert"
  message = "Lambda function {{functionname.name}} p99 duration is approaching its timeout threshold. ${var.notify}"

  query = "avg(last_10m):avg:aws.lambda.duration.p99{app:${var.app},env:${var.env}} by {functionname} > ${var.monitor_config.lambda.duration_p99_threshold_ms}"

  monitor_thresholds {
    critical = var.monitor_config.lambda.duration_p99_threshold_ms
    warning  = floor(var.monitor_config.lambda.duration_p99_threshold_ms * 0.75)
  }

  tags = local.base_tags
}
