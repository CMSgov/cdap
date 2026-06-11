locals {
  # Load defaults, then overlay env-specific config if the file exists
  default_config = yamldecode(file("${path.module}/config/defaults.yml"))

  env_config_path = "${path.module}/config/${var.env}.yml"
  env_config      = fileexists(local.env_config_path) ? yamldecode(file(local.env_config_path)) : {}

  # Merge — env-specific overrides defaults
  vpc_names = concat(
    lookup(local.default_config, "vpcs", []),
    lookup(local.env_config, "vpcs", [])
  )
}
