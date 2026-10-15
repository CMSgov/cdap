locals {
  interface_services = [
    "ssm", "ssmmessages", "ec2messages",
    "kms", "secretsmanager", "logs", "monitoring",
    "sts", "ecr.api", "ecr.dkr",
    "sqs", "sns", "rds"
  ]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.platform.vpc_id
  service_name      = "com.amazonaws.${module.platform.primary_region.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
  tags = { Name = "${module.platform.vpc_name}-s3-gw-endpoint" }
}

resource "aws_security_group" "endpoints" {
  name = "${module.platform.vpc_name}-vpces"
  vpc_id      = module.platform.vpc_id
  description = "For HTTPS to all ${module.platform.vpc_name} interface endpoints"
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_services)
  vpc_id              = module.platform.vpc_id
  service_name        = "com.amazonaws.${module.platform.primary_region.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids = keys(module.platform.private_subnets)
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${module.platform.vpc_name}-vpce-${each.value}" }
}

