# ===========================
# ECS Service Connect Setup
# ===========================
variable "env" {
  default = ""
}
module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards"
  providers   = { aws = aws, aws.secondary = aws.secondary }
  app         = "cdap"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/service-connect-demo"
  service     = "service-connect-demo"
}

locals {
  default_tags = module.standards.default_tags
  service      = "service-connect-demo"
}

# ===========================
# Step 1: Create Cloud Map Namespace
# ===========================

resource "aws_service_discovery_http_namespace" "service_connect" {
  name        = var.namespace_name
  description = "Service Connect namespace for microservices communication"

  tags = {
    Name        = var.namespace_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# ===========================
# Step 2: Create ECS Cluster with Service Connect
# ===========================

resource "aws_ecs_cluster" "main" {
  name = "jjr-microservices-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.service_connect.arn
  }

  tags = {
    Name        = "microservices-cluster"
    Environment = "production"
  }
}

# ===========================
# Step 3: IAM Roles and Policies
# ===========================

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

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

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

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
  name = "ecs-task-policy"
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
# Step 4: Security Group for ECS Tasks
# ===========================

resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
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

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# ===========================
# Step 5: CloudWatch Log Groups
# ===========================

resource "aws_cloudwatch_log_group" "backend_service" {
  name              = "/ecs/backend-service"
  retention_in_days = 7

  tags = {
    Name = "backend-service-logs"
  }
}

resource "aws_cloudwatch_log_group" "frontend_service" {
  name              = "/ecs/frontend-service"
  retention_in_days = 7

  tags = {
    Name = "frontend-service-logs"
  }
}

# ===========================
# Step 6: Backend Service (Server) Task Definition
# ===========================

resource "aws_ecs_task_definition" "backend" {
  family                   = "backend-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "backend"
      image = "539247469933.dkr.ecr.us-east-1.amazonaws.com/testing/nginx:latest" # Replace with your backend image

      portMappings = [
        {
          name          = "backend-port"
          containerPort = 80
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "SERVICE_NAME"
          value = "backend"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "backend-service-task"
  }
}

# ===========================
# Step 7: Backend ECS Service with Service Connect (Server Mode)
# ===========================

resource "aws_ecs_service" "backend" {
  name            = "backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    service {
      port_name      = "backend-port"
      discovery_name = "backend"

      client_alias {
        port     = 80
        dns_name = "backend"
      }

      timeout {
        idle_timeout_seconds       = 300
        per_request_timeout_seconds = 60
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  enable_execute_command = true

  tags = {
    Name = "backend-service"
  }
}

# ===========================
# Step 8: Frontend Service (Client) Task Definition
# ===========================

resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = "nginx:latest" # Replace with your frontend image

      portMappings = [
        {
          name          = "frontend-port"
          containerPort = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "SERVICE_NAME"
          value = "frontend"
        },
        {
          name  = "BACKEND_URL"
          value = "http://backend:80" # Service Connect DNS name
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "frontend-service-task"
  }
}

# ===========================
# Step 9: Frontend ECS Service with Service Connect (Client Mode)
# ===========================

resource "aws_ecs_service" "frontend" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    # Frontend acts as client only, no service block needed
    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  enable_execute_command = true

  tags = {
    Name = "frontend-service"
  }

  depends_on = [aws_ecs_service.backend]
}

# ===========================
# Step 10: Application Load Balancer (Optional - for external access)
# ===========================

resource "aws_lb" "frontend" {
  name               = "frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.private_subnet_ids # Use public subnets for internet-facing ALB

  enable_deletion_protection = false

  tags = {
    Name = "frontend-alb"
  }
}

resource "aws_security_group" "alb" {
  name        = "frontend-alb-sg"
  description = "Security group for frontend ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-alb-sg"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "frontend-tg"
  port        = 8080
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
    Name = "frontend-target-group"
  }
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Update frontend service with load balancer
resource "aws_ecs_service" "frontend_with_alb" {
  name            = "frontend-service-alb"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 8080
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.service_connect.arn

    log_configuration {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend_service.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "service-connect"
      }
    }
  }

  enable_execute_command = true

  tags = {
    Name = "frontend-service-with-alb"
  }

  depends_on = [
    aws_lb_listener.frontend,
    aws_ecs_service.backend
  ]
}
