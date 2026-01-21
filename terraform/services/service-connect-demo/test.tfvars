aws_region = "us-east-1"

vpc_id = "vpc-07cac3327db239c92"

# Private Subnet IDs
# Replace with your actual private subnet IDs
# These subnets should be in different availability zones for high availability
# Example: ["subnet-0a1b2c3d", "subnet-4e5f6g7h"]
private_subnet_ids = [
  "subnet-0c46ebc2dad32d964",
  "subnet-0f26c81d2b603e918",
  "subnet-0c9276af7df0a20eb"
]

# Service Connect Namespace
# The Cloud Map namespace name for service discovery
# Services will be discoverable at <service-name>.<namespace>
namespace_name = "jjr-microservices.local"
