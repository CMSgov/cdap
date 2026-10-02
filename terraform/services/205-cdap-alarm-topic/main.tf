module "alarm_topic" {
  source = "../../modules/topic"

  platform = module.platform
  name     = "alarms"

  sqs_subscriptions    = ["cdap-${module.platform.env}-alarm-to-slack"]
  create_ssm_parameter = true
}
