resource "aws_ecs_task_definition" "this" {
  family                   = var.family_name_override != null ? var.family_name_override : "${var.platform.env}-${var.platform.app}-${var.platform.service}"
  network_mode             = "awsvpc"
  execution_role_arn       = var.task_execution_role_arn != null ? var.task_execution_role_arn : aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = var.task_app_role_arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions    = jsonencode(var.container_definitions_filename)

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = var.volumes[each].value.name
    }
  }

  tags = {
    service = var.service_name_override != null ? var.service_name_override : var.platform.service
  }
}

resource "aws_ecs_service" "this" {
  name                 = var.service_name_override != null ? var.service_name_override : "${var.platform.env}-${var.platform.app}-${var.platform.service}"
  cluster              = var.cluster
  task_definition      = aws_ecs_task_definition.this.arn
  desired_count        = var.desired_count
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = var.force_new_deployment #anytrue([var.force_contracts_deployment, var.contracts_service_image_tag != null])
  propagate_tags       = var.propagate_tags

  tags = {
    service = var.service_name_override != null ? var.service_name_override : var.platform.service
  }

  dynamic "network_configuration" {
    for_each = var.network_configurations
    content {
      subnets          = network_configuration.value.subnets
      assign_public_ip = network_configuration.value.assign_public_ip
      security_groups  = network_configuration.value.security_groups
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }
}

data "aws_iam_policy_document" "ecs_task_execution_policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ssm:GetParameters"
    ]
    resources = ["*"]
  }
}

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
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_policy_attachment" {
  name   = "ecs-task-execution-policy"
  role   = aws_iam_role.ecs_task_execution_role.name
  policy = data.aws_iam_policy_document.ecs_task_execution_policy.json
}
