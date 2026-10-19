module "alarm_topic" {
  # Pinned pre-SNS-delivery-logging to long term retention which is test only. TODO: Update pin after 701-log-retention is applied in prod
  source = "github.com/CMSgov/cdap//terraform/modules/topic?ref=60f80961cb6e9d2a1492cad3dc4f1d584f32fa17"

  platform = module.platform
  name     = "alarms"

  sqs_subscriptions    = ["cdap-${module.platform.env}-alarm-to-slack"]
  create_ssm_parameter = true
}
