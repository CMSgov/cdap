locals {
  default_rule_name = "${var.platform.app}-${var.platform.env}-${var.name}"
  rule_name         = coalesce(var.rule_name_override, local.default_rule_name)

  # Targets flagged lambda_permission get an invoke permission scoped to this rule. The flag is
  # set in configuration rather than inferred from the ARN, so for_each keys are known at plan
  # time even when the function is created in the same apply.
  lambda_targets = { for k, t in var.targets : k => t if t.lambda_permission }
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = local.rule_name
  description         = var.description
  event_bus_name      = var.event_bus_name
  schedule_expression = var.schedule_expression
  event_pattern       = var.event_pattern
  state               = var.enabled ? "ENABLED" : "DISABLED"

  lifecycle {
    precondition {
      condition     = (var.schedule_expression == null) != (var.event_pattern == null)
      error_message = "Set exactly one of schedule_expression or event_pattern."
    }

    precondition {
      condition     = var.schedule_expression == null || var.event_bus_name == "default"
      error_message = "schedule_expression is only supported on the default event bus."
    }

    precondition {
      condition     = length(local.rule_name) <= 64
      error_message = "Rule name ${local.rule_name} is longer than 64 characters. Shorten var.name or set rule_name_override."
    }
  }
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = var.targets

  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = var.event_bus_name
  target_id      = each.key
  arn            = each.value.arn
  role_arn       = each.value.role_arn
  input          = each.value.input
  input_path     = each.value.input_path

  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [each.value.input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  dynamic "dead_letter_config" {
    for_each = each.value.dead_letter_arn != null ? [each.value.dead_letter_arn] : []
    content {
      arn = dead_letter_config.value
    }
  }

  dynamic "retry_policy" {
    for_each = each.value.retry_policy != null ? [each.value.retry_policy] : []
    content {
      maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
      maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
    }
  }
}

resource "aws_lambda_permission" "this" {
  for_each = local.lambda_targets

  # Statement IDs are capped at 100 characters and must be unique per function.
  statement_id  = substr("AllowEventBridge-${local.rule_name}-${each.key}", 0, 100)
  action        = "lambda:InvokeFunction"
  function_name = each.value.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
