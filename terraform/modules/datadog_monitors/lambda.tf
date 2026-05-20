# lambda.tf

resource "datadog_monitor" "lambda_errors" {
  name    = "[${upper(var.env)}] [${var.app}] Lambda — Error Rate High"
  type    = "metric alert"
  message = "Lambda function {{functionname.name}} has a high error rate.\n${var.monitor_config.notification_channel}"

  query = join("", [
    "sum(last_5m):(",
    "sum:aws.lambda.errors{app:${var.app},env:${var.env}} by {functionname}",
    " / ",
    "sum:aws.lambda.invocations{app:${var.app},env:${var.env}} by {functionname}",
    ") * 100 > ${var.monitor_config.lambda.error_rate_threshold}"
  ])

  monitor_thresholds {
    critical = var.monitor_config.lambda.error_rate_threshold
  }

  tags = ["app:${var.app}", "env:${var.env}", "service:lambda", "managed-by:tofu"]
}
