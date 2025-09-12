resource "aws_ecs_task_definition" "this" {
  family             = var.family_name_override != null ? var.family_name_override : "${var.platform.env}-${var.platform.app}-${var.platform.service}"
  network_mode       = "awsvpc"
  execution_role_arn = var.task_execution_role_arn != null ? var.task_execution_role_arn : aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = var.task_app_role_arn
  requires_compatibilities = ["FARGATE"]
  cpu                = var.cpu
  memory             = var.memory
  container_definitions = nonsensitive(jsonencode([
    {
      name                   = var.service_name_override != null ? var.service_name_override : var.platform.service
      image                  = var.image
      readonlyRootFilesystem = true
      essential              = true
      portMappings           = var.port_mappings
      mountPoints            = var.mount_points
      secrets                = var.container_secrets
      environment            = var.container_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/fargate/${var.platform.env}-${var.platform.app}/${var.service_name_override != null ? var.service_name_override : var.platform.service}"
          awslogs-create-group  = "true"
          awslogs-region        = var.platform.primary_region.name
          awslogs-stream-prefix = "${var.platform.env}-${var.platform.app}"
        }
      }
      healthCheck = null
    }
  ]))

  dynamic "volume" {
    for_each = var.volume != null ? var.volume : {}

    content {
      configure_at_launch = var.volume.value.configure_at_launch

      dynamic "docker_volume_configuration" {
        for_each = var.volume.value.docker_volume_configuration != null ? [var.volume.value.docker_volume_configuration] : []

        content {
          autoprovision = var.volume.docker_volume_configuration.value.autoprovision
          driver        = var.volume.docker_volume_configuration.value.driver
          driver_opts   = var.volume.docker_volume_configuration.value.driver_opts
          labels        = var.volume.docker_volume_configuration.value.labels
          scope         = var.volume.docker_volume_configuration.value.scope
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = var.volume.value.efs_volume_configuration != null ? [var.volume.value.efs_volume_configuration] : []

        content {
          dynamic "authorization_config" {
            for_each = var.volume.efs_volume_configuration.value.authorization_config != null ? [var.volume.efs_volume_configuration.value.authorization_config] : []

            content {
              access_point_id = var.volume.authorization_config.value.access_point_id
              iam             = var.volume.authorization_config.value.iam
            }
          }

          file_system_id          = var.volume.efs_volume_configuration.value.file_system_id
          root_directory          = var.volume.efs_volume_configuration.value.root_directory
          transit_encryption      = var.volume.efs_volume_configuration.value.transit_encryption
          transit_encryption_port = var.volume.efs_volume_configuration.value.transit_encryption_port
        }
      }
      name = var.volume.name
    }
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

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_cloudwatch_log_group && var.enable_cloudwatch_logging ? 1 : 0

  name              = var.cloudwatch_log_group_use_name_prefix ? null : var.platform.service
  name_prefix       = var.cloudwatch_log_group_use_name_prefix ? var.platform.service : null
  log_group_class   = var.cloudwatch_log_group_class
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  kms_key_id        = var.cloudwatch_log_group_kms_key_id

  tags = {
    service = var.service_name_override != null ? var.service_name_override : var.platform.service
  }
}
