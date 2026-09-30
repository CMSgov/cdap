# Move pre-existing CloudWatch log groups into the shared module.
moved {
  from = aws_cloudwatch_log_group.app
  to   = module.app_logs.aws_cloudwatch_log_group.this
}

moved {
  from = aws_cloudwatch_log_group.datadog[0]
  to   = module.datadog_logs[0].aws_cloudwatch_log_group.this
}
