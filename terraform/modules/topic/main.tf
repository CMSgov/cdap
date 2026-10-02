locals {
  default_topic_name = "${var.platform.app}-${var.platform.env}-${var.name}"
  topic_name         = coalesce(var.topic_name_override, local.default_topic_name)
  kms_key_id         = coalesce(var.kms_key_override, var.platform.kms_alias_primary.target_key_arn)

  default_ssm_parameter_name = "/${var.platform.app}/${var.platform.env}/${var.platform.service}/nonsensitive/${var.name}-topic-arn"
  ssm_parameter_name         = coalesce(var.ssm_parameter_name_override, local.default_ssm_parameter_name)
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "this" {
  name              = local.topic_name
  display_name      = local.topic_name
  kms_master_key_id = local.kms_key_id
}

data "aws_sqs_queue" "subscriptions" {
  for_each = toset(var.sqs_subscriptions)
  name     = each.value
}

resource "aws_sns_topic_subscription" "sqs" {
  for_each  = data.aws_sqs_queue.subscriptions
  topic_arn = aws_sns_topic.this.arn
  protocol  = "sqs"
  endpoint  = each.value.arn
}

resource "aws_sns_topic_subscription" "additional" {
  for_each  = { for s in var.additional_subscriptions : "${s.protocol}-${s.endpoint}" => s }
  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint
}

resource "aws_ssm_parameter" "topic_arn" {
  count = var.create_ssm_parameter ? 1 : 0

  name  = local.ssm_parameter_name
  value = aws_sns_topic.this.arn
  type  = "String"

  tags = {
    Name = local.ssm_parameter_name
  }
}
