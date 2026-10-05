resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.platform.vpc_id
  service_name      = "com.amazonaws.${module.platform.primary_region.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
  tags = merge(module.platform.default_tags, { Name = "${var.app}-east-${var.env}}-s3-gw-endpoint" })
}
