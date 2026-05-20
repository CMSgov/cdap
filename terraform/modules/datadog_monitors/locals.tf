locals {
  notify = var.notify

  base_tags = [
    "app:${var.app}",
    "env:${var.env}",
    "managed-by:tofu",
  ]
}
