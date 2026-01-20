# AWS Region
# Specify the AWS region where resources will be deployed
aws_region = "us-east-1"

# VPC Configuration
# Replace with your actual VPC ID
# Example: vpc-0a1b2c3d4e5f6g7h8
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"

# Private Subnet IDs
# Replace with your actual private subnet IDs
# These subnets should be in different availability zones for high availability
# Example: ["subnet-0a1b2c3d", "subnet-4e5f6g7h"]
private_subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",
  "subnet-yyyyyyyyyyyyyyyyy"
]

# Service Connect Namespace
# The Cloud Map namespace name for service discovery
# Services will be discoverable at <service-name>.<namespace>
namespace_name = "microservices.local"
