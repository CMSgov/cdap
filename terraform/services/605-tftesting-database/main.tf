locals {
  tftesting_config = yamldecode(file("${path.module}/config/default.yml"))["tftesting"]

  # config/default.yml is the only control here -- no automated override.
  # "off"     -> cluster fully destroyed.
  # "idle"    -> cluster exists, zero instances, no compute cost.
  # "running" -> cluster exists with a live instance.
  tftesting_state          = local.tftesting_config.state
  tftesting_cluster_exists = contains(["idle", "running"], local.tftesting_state)
  tftesting_instance_count = local.tftesting_state == "running" ? 1 : 0
}

data "aws_ssm_parameter" "cloudwatch_alarms_topic_arn" {
  name = "/${module.platform.app}/${module.platform.env}/cdap-alarm-topic/nonsensitive/alarms-topic-arn"
}

module "database" {
  count  = local.tftesting_cluster_exists ? 1 : 0
  source = "../../modules/aurora" 

  platform = module.platform
  username = var.username
  manage_breakglass_password = true
  breakglass_rotation_days   = 2

  instance_class     = var.instance_class
  instance_count     = local.tftesting_instance_count
  maintenance_window = var.maintenance_window
  backup_window      = var.backup_window

  # Throwaway infra: never block teardown, never enroll in backup plans.
  deletion_protection = false
  aws_backup_tag      = null

  # Turns on the IAM auth *capability* only. No Postgres role exists yet --
  # that's created in bootstrap.tf and by consuming terraservices.
  enable_iam_database_authentication = true

  breakglass_alert_sns_topic_arn = data.aws_ssm_parameter.cloudwatch_alarms_topic_arn.value
}
