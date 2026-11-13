locals {
  config_default = yamldecode(file("${path.module}/config/default.yml"))
  config_env     = yamldecode(file("${path.module}/config/${var.env}.yml"))

  infra_enabled    = try(local.config.stack.infra_enabled, true)
  services_enabled = try(local.config.stack.services_enabled, false)

  config = merge(local.config_default, local.config_env, {
    services = merge(local.config_default.services, try(local.config_env.services, {}))
  })
}

check "services_require_infra" {
  assert {
    condition     = !local.services_enabled || local.infra_enabled
    error_message = <<-EOT
      stack.services_enabled is true but stack.infra_enabled is false.
      The target service attaches to the ALB listener and ACM cert created
      under infra_enabled — turn that on first.
    EOT
  }
}
