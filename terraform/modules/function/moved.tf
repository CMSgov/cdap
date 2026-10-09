# This block moves the CloudWatch log group (if pre-existing)
# from the old location to the new location defined in the module.
moved {
  from = aws_cloudwatch_log_group.function
  to   = module.function_logs.aws_cloudwatch_log_group.this
}
