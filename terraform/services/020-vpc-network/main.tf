data "aws_route_tables" "private" {
  vpc_id = module.platform.vpc_id
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}

# S3 Gateway Endpoint (does not leverage security groups)

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.platform.vpc_id
  service_name      = "com.amazonaws.${module.platform.primary_region.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
  tags = {
    Name = "${module.platform.vpc_name}-s3-gw-endpoint"
  }
}

# Endpoint Security Groups
resource "aws_security_group" "endpoints_all" {
  name        = "${module.platform.vpc_name}-vpce-endpoints-all"
  vpc_id      = module.platform.vpc_id
  description = "Interface endpoints available to every provisioned resource and CodeBuild"
}

resource "aws_security_group" "endpoints_build" {
  name        = "${module.platform.vpc_name}-vpce-endpoints-build"
  vpc_id      = module.platform.vpc_id
  description = "Interface endpoints used only during build/provisioning (tofu apply)"
}

# Client Security Groups 
resource "aws_security_group" "vpce_all_clients" {
  name        = "${module.platform.vpc_name}-vpce-all-clients"
  vpc_id      = module.platform.vpc_id
  description = "Membership SG: attach to any resource needing interface endpoint access (every provisioned resource, plus CodeBuild)"
}

resource "aws_security_group" "vpce_platform_clients" {
  name        = "${module.platform.vpc_name}-vpce-build-clients"
  vpc_id      = module.platform.vpc_id
  description = "Membership SG: CodeBuild/CI only — additional build-time-only interface endpoint access"
}

# VPC Endpoints 

resource "aws_vpc_endpoint" "all" {
  for_each            = toset(local.all_interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${module.platform.primary_region.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints_all.id]
  private_dns_enabled = true
  tags = {
    Name = "${module.platform.vpc_name}-vpce-${each.value}"
  }
}

resource "aws_vpc_endpoint" "all_global" {
  for_each            = toset(local.all_global_interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints_all.id]
  private_dns_enabled = true
  tags = {
    Name = "${module.platform.vpc_name}-vpce-${each.value}"
  }
}

resource "aws_vpc_endpoint" "build" {
  for_each            = toset(local.build_interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${module.platform.primary_region.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints_build.id]
  private_dns_enabled = true
  tags = {
    Name = "${module.platform.vpc_name}-vpce-${each.value}"
  }
}

resource "aws_vpc_endpoint" "build_global" {
  for_each            = toset(local.build_global_interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints_build.id]
  private_dns_enabled = true
  tags = {
    Name = "${module.platform.vpc_name}-vpce-${each.value}"
  }
}
