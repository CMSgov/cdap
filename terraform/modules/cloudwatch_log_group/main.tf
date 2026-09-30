locals {
  cdap_env = contains(["prod", "sandbox"], var.env) ? "prod" : "test"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id
  skip_destroy      = var.skip_destroy
}

data "aws_ssm_parameter" "firehose_arn" {
  name = "/cdap/${local.cdap_env}/common/nonsensitive/log-retention/firehose-arn"
}

data "aws_ssm_parameter" "subscription_role_arn" {
  name = "/cdap/${local.cdap_env}/common/nonsensitive/log-retention/subscription-role-arn"
}

resource "aws_cloudwatch_log_subscription_filter" "long_term_retention" {
  name            = "to-shared-${local.cdap_env}-log-retention"
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = ""
  destination_arn = data.aws_ssm_parameter.firehose_arn.value
  role_arn        = data.aws_ssm_parameter.subscription_role_arn.value
}
