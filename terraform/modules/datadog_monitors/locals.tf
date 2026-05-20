locals {
  notify = var.monitor_config.shadow_mode ? "" : var.notify

  base_tags = [
    "application:${var.app}",
    "environment:${var.env}",
    "managed-by:tofu",
    var.monitor_config.shadow_mode ? "shadow-mode:true" : "shadow-mode:false",
  ]
}
