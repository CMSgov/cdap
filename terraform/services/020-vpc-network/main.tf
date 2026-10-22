locals {
  config_dir = "${path.module}/config"

  default_config = yamldecode(file("${local.config_dir}/default.yml"))

  env_config_path        = "${local.config_dir}/${module.platform.app}/${module.platform.env}.yml"
  env_config_path_exists = fileexists(local.env_config_path)
  env_config_path_config = local.env_config_path_exists ? yamldecode(file(local.env_config_path)) : {}

  config = merge(local.default_config, local.env_config_path_config)

  enable_interface_endpoints = local.config.enable_interface_endpoints

  interface_services        = local.enable_interface_endpoints ? local.config.interface_services : []
  global_interface_services = local.enable_interface_endpoints ? local.config.global_interface_services : []
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.platform.vpc_id
  service_name      = "com.amazonaws.${module.platform.primary_region.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
  tags              = { Name = "${module.platform.vpc_name}-s3-gw-endpoint" }
}

resource "aws_security_group" "endpoints" {
  name        = "${module.platform.vpc_name}-vpce-endpoints"
  vpc_id      = module.platform.vpc_id
  description = "For HTTPS to all ${module.platform.vpc_name} interface endpoints"
}

resource "aws_security_group" "endpoint_clients" {
  name        = "${module.platform.vpc_name}-vpce-clients"
  vpc_id      = module.platform.vpc_id
  description = "Membership SG: attach to any resource that needs to reach the interface endpoints"
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${module.platform.primary_region.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${module.platform.vpc_name}-vpce-${each.value}" }
}


resource "aws_vpc_endpoint" "interface_global" {
  for_each            = toset(local.global_interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${module.platform.vpc_name}-vpce-${each.value}" }
}
