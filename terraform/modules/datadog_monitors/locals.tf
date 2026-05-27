locals {
  _notif = var.monitor_config.notifications

  # Emails --> @email@address.com
  _email_channels = [
    for e in local._notif.emails : "@${trimprefix(e, "@")}"
  ]

  # VictorOps --> @victorops-${var.app} (bulk APIs shared org only)
  _victorops_channels = local._notif.victorops ? ["@victorops-${var.app}"] : []

  # Slack -->  @webhook-slack-<channel> (preconfigured slack webhook required)
  _slack_channels = [
    for ch in local._notif.slack : "@webhook-slack-${trimprefix(ch, "@")}"
  ]

  # Escape hatch for non-standard webhooks, like the bluebutton victorops integration
  _additional_webhooks = local._notif.additional_webhooks

  # Composed notify string
  _composed_notify = join(" ", concat(
    local._email_channels,
    local._victorops_channels,
    local._slack_channels,
    local._additional_webhooks
  ))

  # Shadow mode gate — suppress all notifications if shadow_mode = true
  notify = var.monitor_config.shadow_mode ? "" : local._composed_notify

  # Base tags
  base_tags = [
    "application:${var.app}",
    "environment:${var.env}",
    "managed-by:tofu",
    var.monitor_config.shadow_mode ? "shadow-mode:true" : "shadow-mode:false",
  ]
}
