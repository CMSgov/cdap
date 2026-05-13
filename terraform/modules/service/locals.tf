locals {
  service_name      = coalesce(var.service_name_override, var.platform.service)
  service_name_full = "${var.platform.app}-${var.platform.env}-${var.platform.service}"
  service_name      = var.service_name_override != null ? var.service_name_override : var.platform.service
  service_name_full = "${var.platform.app}-${var.platform.env}-${local.service_name}"

  app_container = {
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

  datadog_container = {
    name      = "datadog-agent"
    image     = "public.ecr.aws/datadog/agent:7.50.0"
    essential = false # Do not impact task health if this container fails
    environment = [
      { name = "ECS_FARGATE", value = "true" },
      { name = "DD_SITE", value = "ddog-gov.com" },
      { name = "DD_APM_ENABLED", value = "true" },
      { name = "DD_LOGS_ENABLED", value = "false" }, # DD logging is currently not approved
      { name = "DD_ECS_TASK_COLLECTION_ENABLED", value = "true" }
    ]
    secrets = [{ name = "DD_API_KEY", valueFrom = "/${var.platform.app}/${var.platform.env}/datadog/agents/api_key" }]
  }

  # Build a name → containerPort lookup from port_mappings
  port_map = {
    for pm in coalesce(var.port_mappings, []) :
    pm.name => pm.containerPort
    if pm.name != null && pm.containerPort != null
  }

  sc_port_name = try(
    coalesce(
      var.service_connect_port_name,
      try([for pm in coalesce(var.port_mappings, []) : pm.name if pm.name != null][0], null)
    ),
    null
  )

  # ALB integration is active when a listener ARN is provided
  enable_alb_integration = var.alb_listener_arn != null

  # Resolve the ALB target port by name — caller must provide alb_port_name if using ALB
  alb_container_port = local.enable_alb_integration ? local.port_map[var.alb_port_name] : null
}

