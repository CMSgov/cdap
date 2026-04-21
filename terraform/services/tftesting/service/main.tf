locals {
  default_tags = module.platform.default_tags
}

module "platform" {
  source    = "../../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = "test"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tftesting/service"
  service     = "tftesting"
}

# -------------------------------------------------------
# Cluster
# -------------------------------------------------------
resource "aws_ecs_cluster" "test" {
  name = "cdap-test-tftesting-cluster"

  # Service Connect requires a default namespace on the cluster
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.test.arn
  }
}

# -------------------------------------------------------
# Cloud Map Namespace (required for Service Connect)
# -------------------------------------------------------
resource "aws_service_discovery_http_namespace" "test" {
  name        = "cdap-test-tftesting"
  description = "Service Connect namespace for ECS module testing"
}

# -------------------------------------------------------
# Security Group — sourcing vpc_id from platform module
# -------------------------------------------------------
resource "aws_security_group" "ecs_task" {
  name        = "cdap-test-tftesting-ecs-module-sg"
  description = "Allow inbound HTTP for ECS task test"
  vpc_id      = module.platform.vpc_id # <-- from platform module

  ingress {
    description = "HTTP inbound"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.platform.vpc_cidr] # or hardcode if platform doesn't expose cidr
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------------------------------
# ECS Service Module
# -------------------------------------------------------
module "service" {
  source = "../../../modules/service/"

  # -------------------------------------------------------
  # Platform — passed through from your platform module
  # -------------------------------------------------------
  platform = {
    app     = module.platform.app
    env     = module.platform.env
    service = "tftesting"

    kms_alias_primary = {
      target_key_arn = module.platform.kms_alias_primary.target_key_arn
    }

    primary_region = {
      name = module.platform.primary_region.name
    }

    private_subnets = module.platform.private_subnets
    vpc_id          = module.platform.vpc_id
  }

  cluster_arn = aws_ecs_cluster.test.arn

  image  = "public.ecr.aws/nginx/nginx:latest"
  cpu    = 256
  memory = 512

  port_mappings = [
    {
      name          = "http"
      containerPort = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }
  ]
  service_connect_port_name = "http"
  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/ || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 15
    timeout     = 5
  }

  task_role_arn         = aws_iam_role.task.arn
  security_groups       = [aws_security_group.ecs_task.id]
  desired_count         = 1
  force_new_deployment  = false
  container_environment = []
  container_secrets     = []

  # -------------------------------------------------------
  # Service Connect Testing
  # -------------------------------------------------------
  enable_ecs_service_connect = true
  service_connect_namespace  = aws_service_discovery_http_namespace.test.arn
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }
}
