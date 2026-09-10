locals {
  _notif = try(var.monitor_config.notifications, {})

  _email_channels      = [for e in try(tolist(local._notif.emails), []) : "@${trimprefix(e, "@")}"]
  _slack_webhooks      = try(local._notif.slack, false) ? ["@webhook-slack-${var.app}"] : []
  _additional_webhooks = try(tolist(local._notif.additional_webhooks), [])

  _victorops_channel_prefixes = ["@webhook-victorops-${var.app}"]
  _victorops_notify_strings = [for channel_prefix in local._victorops_channel_prefixes : join("", [
    "{{#is_alert}}${channel_prefix}-critical{{/is_alert}}",
    "{{#is_warning}}${channel_prefix}-warning{{/is_warning}}",
    "{{#is_recovery}}${channel_prefix}-recovery{{/is_recovery}}",
    "{{#is_no_data}}${channel_prefix}-critical{{/is_no_data}}"
  ])]

  _composed_notify = join(" ", concat(
    local._email_channels,
    try(local._notif.victorops, false) ? local._victorops_notify_strings : [],
    local._slack_webhooks,
    local._additional_webhooks
  ))

  notify = local._composed_notify
  base_tags = [
    "application:${var.app}",
    "environment:${var.env}",
    "managed-by:tofu",
  ]

  victorops_notify = join(" ", local._victorops_notify_strings)

  # recommended by Datadog
  # https://docs.datadoghq.com/monitors/configuration/?tab=evaluateddata#evaluation-delay
  aws_evaluation_delay = 900
}
