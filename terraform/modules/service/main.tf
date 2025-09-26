locals {
  service_name = var.service_name_override != null ? var.service_name_override : var.platform.service
}

resource "aws_ecs_task_definition" "this" {
  count = var.execution_role_arn != null ? 0 : 1
  family                   = local.service_name
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn :  aws_iam_role.execution[count.index].arn
  task_role_arn            = var.task_role_arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions = nonsensitive(jsonencode([
    {
      name                   = local.service_name
      image                  = var.image
      readonlyRootFilesystem = true
      portMappings           = var.port_mappings
      mountPoints            = var.mount_points
      secrets                = var.container_secrets
      environment            = var.container_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = var.platform.primary_region.name
          awslogs-stream-prefix = "${var.platform.app}-${var.platform.env}"
        }
      }
      healthCheck = null
    }
  ]))

  dynamic "volume" {
    for_each = var.volume != null ? var.volume : {}

    content {
      name                = var.volume.name
      configure_at_launch = var.volume.value.configure_at_launch

      dynamic "efs_volume_configuration" {
        for_each = var.volume.value.efs_volume_configuration != null ? [var.volume.value.efs_volume_configuration] : []

        content {
          dynamic "authorization_config" {
            for_each = var.volume.value.efs_volume_configuration.authorization_config != null ? [var.volume.value.efs_volume_configuration.authorization_config] : []

            content {
              access_point_id = var.volume.authorization_config.value.access_point_id
              iam             = var.volume.authorization_config.value.iam
            }
          }

          file_system_id     = var.volume.efs_volume_configuration.value.file_system_id
          root_directory     = var.volume.efs_volume_configuration.value.root_directory
          transit_encryption = "ENABLED"
        }
      }
    }
  }
}

resource "aws_ecs_service" "this" {
  count = var.execution_role_arn != null ? 0 : 1
  name                 = "${var.platform.app}-${var.platform.env}-${local.service_name}"
  cluster              = var.cluster_arn
  task_definition      = aws_ecs_task_definition.this[count.index].arn
  desired_count        = var.desired_count
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = var.force_new_deployment
  propagate_tags       = "SERVICE"
  network_configuration {
    subnets          = var.platform.subnets
    assign_public_ip = false
    security_groups  = var.platform.security_groups
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

data "aws_kms_alias" "master_key_alias" {
  name = "alias/${var.platform.kms_alias_primary}"
}

data "aws_iam_policy_document" "execution" {
  count = var.execution_role_arn != null ? 1 : 0
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

  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
    effect    = "Allow"
  }
}

resource "aws_iam_role" "execution" {
  count = var.execution_role_arn != null ? 0 : 1
  name  = "${local.service_name}-execution"
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

resource "aws_iam_role_policy" "execution" {
  count  = var.execution_role_arn != null ? 0 : 1
  name   = "${aws_ecs_task_definition.this[0].family}-execution"
  role   = aws_iam_role.execution[0].name
  policy = data.aws_iam_policy_document.execution[0].json
}
