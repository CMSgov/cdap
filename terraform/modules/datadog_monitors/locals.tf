locals {
  notify = var.monitor_config.shadow_mode ? "" : var.notify

  base_tags = [
    "app:${var.app}",
    "env:${var.env}",
    "environment:${var.env}", # ← required by Datadog org tag policy
    "managed-by:tofu",
    var.monitor_config.shadow_mode ? "shadow-mode:true" : "shadow-mode:false",
  ]
}
