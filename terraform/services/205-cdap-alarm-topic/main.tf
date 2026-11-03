module "alarm_topic" {
  # Pinned pre-SNS-delivery-logging to long term retention which is test only. TODO: Update pin after 701-log-retention is applied in prod
  source = "../../modules/topic"

  platform = module.platform
  name     = "alarms"

  sqs_subscriptions    = ["cdap-${module.platform.env}-alarm-to-slack"]
  create_ssm_parameter = true
}
