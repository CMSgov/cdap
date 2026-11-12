locals {
  config_file = "${path.module}/config/${var.env}.yml"
  config      = fileexists(local.config_file) ? yamldecode(file(local.config_file)) : {}

  # Everything in this terraservice is created only while the flag is on. Turning it off destroys the test resources on the next apply.
  enabled             = coalesce(var.event_rule_enabled, try(local.config.event_rule.enabled, false))
  schedule_expression = try(local.config.event_rule.schedule_expression, "rate(1 day)")

  event_source      = "cdap.tftesting"
  event_detail_type = "tftesting.roundtrip"
}
