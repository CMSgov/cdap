locals {
  config_dir = "${path.module}/config"

  default_config = yamldecode(file("${local.config_dir}/default.yml"))

  env_config_path        = "${local.config_dir}/${module.platform.app}/${module.platform.env}.yml"
  env_config_path_exists = fileexists(local.env_config_path)
  env_config_path_config = local.env_config_path_exists ? yamldecode(file(local.env_config_path)) : {}

  config = merge(local.default_config, local.env_config_path_config)

  enable_interface_endpoints = local.config.enable_interface_endpoints

  all_interface_services          = local.enable_interface_endpoints ? local.config.all_interface_services : []
  all_global_interface_services   = local.enable_interface_endpoints ? local.config.all_global_interface_services : []
  build_interface_services        = local.enable_interface_endpoints ? local.config.build_interface_services : []
  build_global_interface_services = local.enable_interface_endpoints ? local.config.build_global_interface_services : []
}
