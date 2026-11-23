# Exercises modules/event_rule with both trigger modes and both target kinds AB2D uses today:
#   pattern rule  -> Lambda (validated end to end during apply) + SNS topic
#   schedule rule -> Lambda with a fixed input

# The receiver Lambda writes the nonce of each round-trip event here; the check reads it back.
resource "aws_ssm_parameter" "receipt" {
  count = local.enabled ? 1 : 0

  name  = "/cdap/${var.env}/tftesting/event-rule/last-received"
  type  = "String"
  value = "none"

  lifecycle {
    ignore_changes = [value] # written by the Lambda
  }
}

module "receiver_function" {
  count  = local.enabled ? 1 : 0
  source = "../../modules/function"

  platform    = module.platform
  name        = "tftesting-event-rule"
  description = "Ephemeral Lambda that receives EventBridge test events and checks the round trip"

  source_dir          = "${path.module}/lambda_src"
  source_dir_excludes = ["**/__pycache__/**", "**/*.pyc", "**/tests/**"]

  handler      = "lambda_function.function_handler"
  runtime      = "python3.14"
  architecture = "arm64"
  timeout      = 60
  memory_size  = 256

  # Runs the round-trip check. Referencing the rule makes it wait until the rule exists.
  liveness_check_triggers = { rule_arn = module.pattern_rule[0].arn }
  log_retention_days      = 7

  environment_variables = {
    RECEIPT_PARAM     = aws_ssm_parameter.receipt[0].name
    EVENT_BUS_NAME    = "default"
    EVENT_SOURCE      = local.event_source
    EVENT_DETAIL_TYPE = local.event_detail_type
  }

  function_role_inline_policies = {
    "event-rule-roundtrip" = data.aws_iam_policy_document.roundtrip[0].json
  }
}

# SNS target, mirroring AB2D's ECS task-monitoring rule
module "topic" {
  count  = local.enabled ? 1 : 0
  source = "../../modules/topic"

  platform                  = module.platform
  name                      = "tftesting-event-rule"
  allow_eventbridge_publish = true
  log_retention_days        = 7
}

module "pattern_rule" {
  count  = local.enabled ? 1 : 0
  source = "../../modules/event_rule"

  platform    = module.platform
  name        = "tftesting-pattern"
  description = "tftesting: routes ${local.event_source} round-trip events to Lambda and SNS"

  event_pattern = jsonencode({
    source        = [local.event_source]
    "detail-type" = [local.event_detail_type]
  })

  targets = {
    lambda = {
      arn               = module.receiver_function[0].function_arn
      lambda_permission = true
      retry_policy      = { maximum_retry_attempts = 2, maximum_event_age_in_seconds = 300 }
    }
    SendToSNS = { arn = module.topic[0].arn }
  }
}

module "schedule_rule" {
  count  = local.enabled ? 1 : 0
  source = "../../modules/event_rule"

  platform            = module.platform
  name                = "tftesting-schedule"
  description         = "tftesting: invokes the receiver Lambda on a schedule with a fixed input"
  schedule_expression = local.schedule_expression

  targets = {
    lambda = {
      arn               = module.receiver_function[0].function_arn
      lambda_permission = true
      input             = jsonencode({ RequestType = "ScheduledPing" })
    }
  }
}
