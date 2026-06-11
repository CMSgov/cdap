data "aws_vpc" "app" {
  for_each = toset(local.vpc_names)

  tags = {
    Name = each.key
  }
}

# Outbound to Datadog API
resource "aws_vpc_security_group_egress_rule" "private_location_https" {
  security_group_id = module.ecs_datadog_synthetics.task_security_group_id
  description       = "Allow HTTPS egress for Datadog reporting"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# Outbound to app VPCs — driven by config files
resource "aws_vpc_security_group_egress_rule" "private_location_app_vpcs" {
  for_each = data.aws_vpc.app

  security_group_id = module.ecs_datadog_synthetics.task_security_group_id
  description       = "Allow synthetic test traffic to ${each.key} VPC"
  cidr_ipv4         = each.value.cidr_block
  ip_protocol       = "-1"
}
