data "aws_route_tables" "private" {
  vpc_id = module.platform.vpc_id
  filter {
    name   = "tag:Tier"
    values = ["private"]
  }
}