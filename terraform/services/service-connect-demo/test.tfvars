# AWS Region Configuration
aws_region = "us-east-1"

# VPC Configuration
# Replace with your actual VPC ID
vpc_id = "vpc-07cac3327db239c92"

# Private Subnet IDs for ECS Tasks
# Replace with your actual private subnet IDs
private_subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0123456789abcdef1",
  "subnet-0123456789abcdef2"
]

# Public Subnet IDs for Load Balancers
# Replace with your actual public subnet IDs
public_subnet_ids = [
  "subnet-abcdef0123456789a",
  "subnet-abcdef0123456789b",
  "subnet-abcdef0123456789c"
]

# Cloud Map Namespace for Service Connect
namespace_name = "microservices.local"

# Port Mappings for Container
# Example configuration - adjust based on your application needs
port_mappings = [
  {
    name               = "app-port"
    containerPort      = 8080
    hostPort           = 8080
    protocol           = "tcp"
    appProtocol        = "http"
    containerPortRange = null
  }
]
