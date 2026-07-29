locals {
  service_name      = coalesce(var.service_name_override, var.platform.service)
  service_name_full = "${var.platform.app}-${var.platform.env}-${local.service_name}"

  ###############
  # Networking
  ###############

  # ALB integration is active when a listener ARN is provided
  enable_alb_integration = var.enable_alb_integration && var.alb_listener_arn != null
  # Resolve the ALB target port by name — caller must provide alb_port_name if using ALB
  proxy_upstream_port = var.enable_mtls_sidecar ? try(
    [for pm in coalesce(var.port_mappings, []) : pm.containerPort
      if pm.name != "proxy" && pm.containerPort != null
    ][0],
    null
  ) : null

  proxy_port_mapping = local.enable_mtls_sidecar ? [{
    name          = "proxy"
    containerPort = var.proxy_listen_port
    hostPort      = var.proxy_listen_port
    protocol      = "tcp"
  }] : []

  # Merge proxy port into the existing port_mappings for the app container
  effective_port_mappings = concat(
    coalesce(var.port_mappings, []),
    local.proxy_port_mapping
  )

  # When proxy is enabled, ALB targets the proxy port automatically
  effective_alb_port_name     = local.enable_mtls_sidecar ? "proxy" : var.alb_port_name
  alb_container_port          = local.enable_alb_integration ? local.port_map[local.effective_alb_port_name] : null
  use_external_load_balancers = var.load_balancers != null && !local.enable_alb_integration

  ###############
  # App container
  ###############

  # Build a name to containerPort lookup from port_mappings
  port_map = {
    for pm in coalesce(local.effective_port_mappings, []) :
    pm.name => pm.containerPort
    if pm.name != null && pm.containerPort != null
  }

  sc_port_name = try(
    coalesce(
      var.service_connect_port_name,
      local.enable_mtls_sidecar ? "proxy" : try(
        [for pm in coalesce(var.port_mappings, []) : pm.name if pm.name != null][0],
        null
      )
    ),
    null
  )

  image_tag_service_name = coalesce(
    var.image_tag_service_name_override,
    local.service_name
  )
  ecr_repository_url = var.ecr_repository_url != null ? var.ecr_repository_url : (
    "${var.platform.account_id}.dkr.ecr.${var.platform.primary_region.name}.amazonaws.com/${var.platform.app}-${local.image_tag_service_name}"
  )

  current_image = var.image != null ? var.image : "${local.ecr_repository_url}:${aws_ssm_parameter.image_tag.value}"

  app_container = {
    name                   = local.service_name
    image                  = local.current_image
    readonlyRootFilesystem = var.readonly_root_filesystem
    portMappings           = var.port_mappings
    mountPoints            = var.mount_points
    secrets = concat(
      var.container_secrets,
      [
        {
          name      = "DD_VERSION"
          valueFrom = aws_ssm_parameter.image_tag.arn
        }
      ]
    )
    command = var.command
    environment = concat(
      var.container_environment,
      [
        { name = "DD_ENV", value = var.platform.env },
        { name = "DD_SERVICE", value = local.service_name },
        { name = "DD_TAGS", value = "environment:${var.platform.env}, application:${var.platform.app}, service:${local.service_name}" },
      ],
      var.enable_datadog_agent ? [
        { name = "DD_AGENT_HOST", value = "localhost" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_DOGSTATSD_PORT", value = "8125" },   # Default
        { name = "DD_TRACE_AGENT_PORT", value = "8126" }, # Default
      ] : []
    )
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.platform.primary_region.name
        awslogs-stream-prefix = "${var.platform.app}-${var.platform.env}"
      }
    }
    healthCheck = var.health_check
  }

  ###############
  # mTLS Proxy
  ###############
  enable_mtls_sidecar = var.mtls_cert_arn != null ? true : false
  mtls_image          = local.enable_mtls_sidecar ? "${var.platform.account_id}.dkr.ecr.${var.platform.primary_region.name}.amazonaws.com/cdap-mtls-sidecar:${data.aws_ssm_parameter.mtls_image_tag[0].value}" : null
  proxy_container = {
    name                   = "proxy"
    image                  = local.mtls_image
    essential              = true
    readonlyRootFilesystem = true

    mountPoints = [
      {
        sourceVolume  = "proxy-certs"
        containerPath = "/etc/certs"
        readOnly      = false
      }
    ]

    portMappings = local.proxy_port_mapping

    environment = [
      { name  = "ACM_CERTIFICATE_ARN"
        value = var.mtls_cert_arn
      },
      {
        name  = "UPSTREAM_URL"
        value = "http://localhost:${local.proxy_upstream_port}"
      },
      {
        name  = "PROXY_LISTEN_PORT"
        value = tostring(var.proxy_listen_port)
      },
      {
        name  = "REQUIRE_CLIENT_CERT"
        value = "true"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.platform.primary_region.name
        awslogs-stream-prefix = "proxy"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8081/health || exit 1"]
      interval    = 30
      retries     = 3
      startPeriod = 15
      timeout     = 5
    }

    dependsOn = []
  }


  ###############
  # Datadog container
  ###############
  datadog_container = {
    name                   = "datadog-agent"
    image                  = "public.ecr.aws/datadog/agent:7.80.4"
    essential              = false # Do not impact task health if this container fails
    readonlyRootFilesystem = true

    healthCheck = {
      command     = ["CMD", "/opt/datadog-agent/bin/agent/agent", "health"]
      interval    = 30
      retries     = 3
      startPeriod = 15
      timeout     = 5
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.enable_datadog_agent ? aws_cloudwatch_log_group.datadog[0].name : ""
        awslogs-region        = var.platform.primary_region.name
        awslogs-stream-prefix = "${var.platform.app}-${var.platform.env}"
      }
    }

    mountPoints = [
      {
        sourceVolume  = "datadog-run"
        containerPath = "/var/run/datadog"
        readOnly      = false
      },
      {
        sourceVolume  = "datadog-tmp"
        containerPath = "/tmp"
        readOnly      = false
      },
      {
        sourceVolume  = "datadog-etc"
        containerPath = "/etc/datadog-agent"
        readOnly      = false
      },
      {
        sourceVolume  = "datadog-confd"
        containerPath = "/etc/datadog-agent/conf.d"
        readOnly      = false
      }
    ]

    environment = [
      { name = "ECS_FARGATE", value = "true" },
      { name = "DD_APM_ENABLED", value = "true" },
      { name = "DD_APM_NON_LOCAL_TRAFFIC", value = "true" },
      { name = "DD_APM_RECEIVER_PORT", value = "8126" },
      { name = "DD_APM_TELEMETRY_ENABLED", value = "false" },
      { name = "DD_DATA_STREAMS_ENABLED", value = "false" },
      { name = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value = "true" },
      { name = "DD_DOGSTATSD_PORT", value = "8125" }, # Default
      { name = "DD_ECS_TASK_COLLECTION_ENABLED", value = "true" },
      { name = "DD_ENV", value = var.platform.env },
      { name = "DD_LOGS_ENABLED", value = "false" }, # DD logging is currently not approved
      { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
      { name = "DD_SERVICE", value = local.service_name },
      { name = "DD_SITE", value = "ddog-gov.com" },
      { name = "DD_TAGS", value = "application:${var.platform.app}, service:${local.service_name}" },
    ]
    secrets = [{ name = "DD_API_KEY", valueFrom = data.aws_ssm_parameter.datadog_api_key.name }]
  }
}

##################
# Cloudwatch
##################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.platform.kms_alias_primary.target_key_arn

  tags = {
    Name = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}"
  }
}

resource "aws_cloudwatch_log_group" "datadog" {
  count             = var.enable_datadog_agent ? 1 : 0
  name              = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}/datadog-agent"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.platform.kms_alias_primary.target_key_arn

  tags = {
    Name = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}/datadog-agent"
  }
}

# Versioning
resource "aws_ssm_parameter" "image_tag" {
  name   = "/${var.platform.app}/${var.platform.env}/nonsensitive/${local.service_name}/image-tag"
  type   = "SecureString"
  key_id = var.platform.kms_alias_primary.target_key_arn
  # Placeholder — will be overwritten by the build workflow on first push
  value = "initial"

  lifecycle {
    # Never let Tofu overwrite a real tag written by the workflow
    ignore_changes = [value]
  }
}

##################
# ECS Service
##################
resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name_full
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
  task_role_arn            = aws_iam_role.task.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  # Concat the main container with the datadog container
  container_definitions = nonsensitive(jsonencode(
    concat(
      [local.app_container],
      var.enable_datadog_agent ? [local.datadog_container] : [],
      local.enable_mtls_sidecar ? [local.proxy_container] : [] # ← missing
    )
  ))

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.enable_mtls_sidecar ? ["proxy-certs"] : []
    content {
      name = volume.value
    }
  }

  dynamic "volume" {
    for_each = var.enable_datadog_agent ? [
      "datadog-run",
      "datadog-tmp",
      "datadog-etc",
      "datadog-confd"
    ] : []
    content {
      name = volume.value
    }
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


resource "aws_security_group" "task" {
  count       = (length(var.security_groups) == 0) ? 1 : 0
  name        = "${local.service_name_full}-task-sg"
  description = "ECS task security group for ${local.service_name_full}"
  vpc_id      = var.platform.vpc_id

  # No inline ingress or egress rules — all dependent rules managed externally
  # via aws_security_group_rule in the caller to avoid conflicts.

  tags = {
    Name = "${local.service_name_full}-task-sg"
  }
}

resource "aws_ecs_service" "this" {
  name                   = local.service_name_full
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.this.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  platform_version       = "1.4.0"
  force_new_deployment   = var.force_new_deployment
  propagate_tags         = "SERVICE"
  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.subnets == null ? [for s in var.platform.private_subnets : s.id] : var.subnets
    assign_public_ip = false
    security_groups  = (length(var.security_groups) == 0) ? [aws_security_group.task[0].id] : var.security_groups
  }

  dynamic "load_balancer" {
    for_each = local.enable_alb_integration ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name = local.enable_mtls_sidecar ? "proxy" : (
        var.service_name_override != null ? var.service_name_override : local.service_name
      )
      container_port = local.alb_container_port
    }
  }

  # Old interface: caller-provided load_balancers (deprecated, maintained for backwards compatibility)
  dynamic "load_balancer" {
    for_each = local.use_external_load_balancers ? coalesce(var.load_balancers, []) : []
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = coalesce(load_balancer.value.container_name, local.service_name) #
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_connect_configuration" {
    for_each = var.enable_ecs_service_connect ? [1] : []
    content {
      enabled   = true
      namespace = var.service_connect_namespace.arn

      service {
        discovery_name = local.service_name
        port_name      = local.sc_port_name

        client_alias {
          port     = coalesce(var.service_connect_client_port, local.port_map[local.sc_port_name])
          dns_name = local.service_name
        }

        tls {
          kms_key  = var.platform.kms_alias_primary.target_key_arn
          role_arn = aws_iam_role.service_connect[0].arn

          issuer_cert_authority {
            aws_pca_authority_arn = one(data.aws_ram_resource_share.pace_ca.resource_arns)
          }
        }
      }
    }
  }
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  depends_on = [
    aws_cloudwatch_log_group.app,
    aws_cloudwatch_log_group.datadog,
    aws_lb_listener_rule.this,
    aws_iam_role_policy_attachment.service_connect,
    aws_iam_role.service_connect
  ]

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker.enable
    rollback = var.deployment_circuit_breaker.rollback
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# -------------------------------------------------------
# ALB and Networking
# -------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "https" {
  count             = (length(var.security_groups) == 0) ? 1 : 0
  security_group_id = aws_security_group.task[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS outbound (ECR, CloudWatch, SSM)"
}

locals {
  # AWS target group name limit is 32 characters
  target_group_name = substr("${local.service_name_full}-tg", 0, 32)
}

resource "aws_lb_target_group" "this" {
  count = var.enable_alb_integration ? 1 : 0

  name        = local.target_group_name
  port        = local.alb_container_port
  protocol    = var.alb_target_group_protocol
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
      condition     = local.enable_mtls_sidecar || var.alb_port_name != null
      error_message = "alb_port_name is required when alb_listener_arn is set and enable_mtls_sidecar is false. Set it to the name of the port mapping in port_mappings that should receive ALB traffic."
    }

    precondition {
      condition = (
        local.enable_mtls_sidecar ||
        var.alb_port_name == null ||
        contains(keys(local.port_map), var.alb_port_name)
      )
      error_message = "alb_port_name '${coalesce(var.alb_port_name, "(null)")}' does not match any named port in port_mappings. Available ports: ${join(", ", keys(local.port_map))}"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.service_connect
  ]
}

resource "aws_lb_listener_rule" "this" {
  count = var.enable_alb_integration ? 1 : 0

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
