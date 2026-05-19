## Use DPC platform module to use cross-team KMS keys
module "dpc_platform" {
  providers = { aws = aws, aws.secondary = aws.secondary }

  source      = "../../modules/platform"
  app         = "dpc"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}

## DPC Test cloudwatch metric alarm
resource "aws_sns_topic" "cloudwatch_alarms" {
  name              = "${module.platform.app}-${module.platform.env}-cloudwatch-alarms"
  kms_master_key_id = module.dpc_platform.kms_alias_primary.target_key_arn
}

resource "aws_sns_topic_subscription" "alarms_sqs" {
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "sqs"
  endpoint  = module.sns_to_slack_queue.arn
}

resource "aws_cloudwatch_metric_alarm" "test" {
  alarm_name          = "${module.platform.app}-${module.platform.env}-test-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "TestMetric"
  namespace           = "TestNamespace"
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  alarm_description  = "Test alarm — use set-alarm-state to trigger manually"
  alarm_actions      = [aws_sns_topic.cloudwatch_alarms.arn]
  ok_actions         = [aws_sns_topic.cloudwatch_alarms.arn]
  treat_missing_data = "missing" # Stays INSUFFICIENT_DATA, not ALARM
}
