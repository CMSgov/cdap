data "aws_ram_resource_share" "pace_ca" {
  resource_owner = "OTHER-ACCOUNTS"
  name           = "pace-ca-g1"
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name_full
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
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
      healthCheck = var.health_check
    }
  ]))

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = var.volumes != null ? toset(var.volumes) : toset([])

    content {
      name                = volume.value.name
      configure_at_launch = volume.value.configure_at_launch

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []

        content {
          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []

            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }

          file_system_id     = efs_volume_configuration.value.file_system_id
          root_directory     = efs_volume_configuration.value.root_directory
          transit_encryption = "ENABLED"
        }
      }
    }
  }
}

resource "aws_ecs_service" "this" {
  name                 = local.service_name_full
  cluster              = var.cluster_arn
  task_definition      = aws_ecs_task_definition.this.arn
  desired_count        = var.desired_count
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = var.force_new_deployment
  propagate_tags       = "SERVICE"

  network_configuration {
    subnets          = var.subnets == null ? [for s in var.platform.private_subnets : s.id] : var.subnets
    assign_public_ip = false
    security_groups  = var.security_groups
  }

  dynamic "load_balancer" {
    for_each = local.enable_alb_integration ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.service_name
      container_port   = local.alb_container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.enable_ecs_service_connect ? [1] : []
    content {
      enabled   = true
      namespace = var.service_connect_namespace

      service {
        discovery_name = local.service_name
        port_name      = local.sc_port_name

        client_alias {
          port     = local.port_map[local.sc_port_name]
          dns_name = local.service_name
        }

        tls {
          kms_key  = var.platform.kms_alias_primary.target_key_arn
          role_arn = aws_iam_role.service_connect[0].arn

          issuer_cert_authority {
            aws_pca_authority_arn = [one(data.aws_ram_resource_share.pace_ca.resource_arns)]
          }
        }
      }
    }
  }
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  depends_on = [
    aws_lb_listener_rule.this
  ]

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker.enable
    rollback = var.deployment_circuit_breaker.rollback
  }

  lifecycle {
    ignore_changes = var.ignore_desired_count_changes ? [desired_count] : []
  }
}

# -------------------------------------------------------
# ALB
# -------------------------------------------------------

resource "aws_lb_target_group" "this" {
  count = local.enable_alb_integration ? 1 : 0

  name        = "${local.service_name_full}-tg"
  port        = local.alb_container_port
  protocol    = "HTTP"
  vpc_id      = var.platform.vpc_id
  target_type = "ip"

  health_check {
    path                = var.alb_health_check.path
    port                = var.alb_health_check.port
    protocol            = var.alb_health_check.protocol
    matcher             = var.alb_health_check.matcher
    interval            = var.alb_health_check.interval
    timeout             = var.alb_health_check.timeout
    healthy_threshold   = var.alb_health_check.healthy_threshold
    unhealthy_threshold = var.alb_health_check.unhealthy_threshold
  }

  tags = {
    Name = "${local.service_name_full}-tg"
  }

  lifecycle {
    precondition {
      condition     = var.alb_port_name != null
      error_message = "alb_port_name is required when alb_listener_arn is set. Set it to the name of the port mapping in port_mappings that should receive ALB traffic."
    }

    precondition {
      condition     = var.alb_port_name == null || contains(keys(local.port_map), var.alb_port_name)
      error_message = "alb_port_name '${var.alb_port_name}' does not match any named port in port_mappings."
    }
  }

  depends_on = [
    aws_lb_listener_rule.this,
    aws_iam_role_policy_attachment.service_connect
  ]
}

resource "aws_lb_listener_rule" "this" {
  count = local.enable_alb_integration ? 1 : 0

  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = var.alb_path_patterns
    }
  }
}
