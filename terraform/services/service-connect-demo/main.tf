terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}
# ===========================
# ECS Service Connect Setup
# ===========================
locals {
  default_tags            = module.platform.default_tags
  service                 = "service-connect-demo"
  api_image_uri           = "539247469933.dkr.ecr.us-east-1.amazonaws.com/testing/nginx"
  ecs_task_def_cpu_api    = 4096
  ecs_task_def_memory_api = 14336
  api_desired_instances   = 1
  container_port          = 8080
  force_api_deployment    = true
}

module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=plt-1448_test_service_connect"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = "test"
  root_module = "https://github.com/CMSgov/cdap/tree/plt-1448_test_service_connect/terraform/services/service-connect-demo"
  service     = local.service
}

module "cluster" {
  source                = "github.com/CMSgov/cdap//terraform/modules/cluster?ref=plt-1448_test_service_connect"
  cluster_name_override = "plt-1448-microservices-cluster"
  platform              = module.platform
}

# ===========================
# Data Sources
# ===========================

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ===========================
# IAM Roles and Policies
# ===========================

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "jjr-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "jjr-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "jjr-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# ===========================
# Security Groups
# ===========================

resource "aws_security_group" "ecs_tasks" {
  name        = "jjr-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow all traffic from within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}

resource "aws_security_group" "load_balancer" {
  name        = "jjr-load-balancer-sg"
  description = "Security group for load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "load-balancer-sg"
  }
}

# ===========================
# Load Balancer for Backend Service
# ===========================

resource "aws_lb" "backend" {
  name               = "sc-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = var.public_subnet_ids # Use public subnets for internet-facing ALB

  enable_deletion_protection = false

  tags = {
    Name = "backend-alb"
  }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "cdap-backend-tg"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
  }

  tags = {
    Name = "cdap-backend-target-group"
  }
}

data "aws_ecs_cluster" "demo_cluster" {
  cluster_name = "jjr2-microservices-cluster"
}

module "backend_service" {
  source                = "github.com/CMSgov/cdap//terraform/modules/service?ref=plt-1448_test_service_connect"
  service_name_override = "backend-service"
  platform              = module.platform
  cluster_arn           = data.aws_ecs_cluster.demo_cluster.arn
  image                 = local.api_image_uri
  cpu                   = local.ecs_task_def_cpu_api
  memory                = local.ecs_task_def_memory_api
  desired_count         = local.api_desired_instances
  security_groups       = [aws_security_group.ecs_tasks.id, aws_security_group.load_balancer.id]
  task_role_arn         = aws_iam_role.ecs_task_role.arn
  port_mappings = [
    {
      name          = "backend-port"
      containerPort = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }
  ]
  force_new_deployment = local.force_api_deployment

  load_balancers = [{
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = local.service
    container_port   = local.container_port
  }]

  mount_points = [
    {
      "containerPath" = "/var/log/*",
      "readOnly"      = false,
      "sourceVolume"  = "var_log",
    },
    {
      "sourceVolume" : "nginx-cache",
      "readOnly" = false,
      "containerPath" : "/var/cache/nginx/*"
    },
  ]

  volumes = [
    {
      name     = "nginx-cache"
      readOnly = false
    },
    {
      name     = "var_log"
      readOnly = false
    },
  ]

}
