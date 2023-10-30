# Security Groups
#
# Find the security group for the Cisco VPN
#
data "aws_security_group" "vpn" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-vpn-private"]
  }
}

# Find the management group
#
data "aws_security_group" "tools" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-enterprise-tools"]
  }
}

# Find the tools group
#
data "aws_security_group" "management" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-remote-management"]
  }
}

# Find the EFS group
#
data "aws_security_group" "efs" {
  filter {
    name   = "group-name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-efs"]
  }
}

# VPC
#
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-vpc"]
  }
}

# Subnets
#
# One for each availability zone
#
data "aws_subnet" "az1" {
  vpc_id = local.vpc_id
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-az1-data"]
  }
}

data "aws_subnet" "az2" {
  vpc_id = local.vpc_id
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_subnet_security_group_service_name}-${var.environment_name}-az2-data"]
  }
}
