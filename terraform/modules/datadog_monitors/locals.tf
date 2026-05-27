locals {
  _notif = try(var.monitor_config.notifications, {})

  _email_channels      = [for e in try(tolist(local._notif.emails), []) : "@${trimprefix(e, "@")}"]
  _victorops_channels  = try(local._notif.victorops, false) ? ["@victorops-${var.app}"] : []
  _slack_webhooks      = try(local._notif.slack, false) ? ["@webhook-slack-${var.app}"] : []
  _additional_webhooks = try(tolist(local._notif.additional_webhooks), [])

  _composed_notify = join(" ", concat(
    local._email_channels,
    local._victorops_channels,
    local._slack_webhooks,
    local._additional_webhooks
  ))

  notify = var.monitor_config.shadow_mode ? "" : local._composed_notify
  base_tags = [
    "application:${var.app}",
    "environment:${var.env}",
    "managed-by:tofu",
    var.monitor_config.shadow_mode ? "shadow-mode:true" : "shadow-mode:false",
  ]
}
