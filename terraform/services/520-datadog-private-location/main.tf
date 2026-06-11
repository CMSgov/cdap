##
# Datadog Synthetics
##

resource "datadog_synthetics_private_location" "this" {
  name        = "cdap-${module.platform.account_env_suffix}"
  description = "Private location running in CDAP VPC for synthetic testing"
  tags        = ["environment:${var.env}", "managed-by:tofu"]
}

resource "aws_ssm_parameter" "private_location_config" {
  name        = "/cdap/${var.env}/datadog/sensitive/private-location-config"
  description = "Datadog synthetic private location configuration JSON"
  type        = "SecureString"
  value       = datadog_synthetics_private_location.cdap.config

  tags = {
    Name = "/cdap/${var.env}/datadog/sensitive/private-location-config"
  }
}

##
# Cluster
##
module "cdap_cluster" {
  source   = "../../modules/ecs-cluster"
  platform = module.standards.platform
}

##
# Service
###
module "ecs_datadog_synthetics" {
  source      = "../../../modules/service/"
  cluster_arn = aws_ecs_cluster.datadog.arn

  platform = module.platform

  image            = "datadog/synthetics-private-location-worker:1.68.0"
  cpu              = 512
  memory           = 1024
  cpu_architecture = "X86_64" # Datadog worker image is x86 only — do not use ARM64
  desired_count    = 1

  container_secrets = [
    {
      name      = "DD_PRIVATE_LOCATION_CONFIG"
      valueFrom = aws_ssm_parameter.private_location_config.arn
    }
  ]

  container_environment = [
    {
      name  = "DD_SITE"
      value = "ddog-gov.com"
    },
    {
      name  = "LOG_LEVEL"
      value = "info"
    }
  ]

  health_check = {
    command     = ["CMD", "/usr/local/bin/synthetics-pl", "healthcheck"]
    interval    = 30
    retries     = 3
    startPeriod = 60
    timeout     = 5
  }

  # No ALB needed as this service makes outbound calls only
  alb_listener_arn = null

  # No inbound ports needed, Datadog private location is a pull based service
  port_mappings = null

  enable_datadog_agent = false # Don't run a DD agent sidecar inside the DD agent itself

  deployment_circuit_breaker = {
    enable   = true
    rollback = true # Auto-rollback is safe here — no stateful issues
  }

  ignore_desired_count_changes = false # Currently no autoscaling needed for the PL worker
}

resource "aws_ssm_parameter" "private_location_id" {
  name        = "/cdap/${module.platform.account_env_suffix}/common/nonsensitive/datadog/synthetics_location_id"
  description = "Datadog synthetics private location ID for CDAP in VPC ${var.env} in account ${module.platform.account_env_suffix}"
  type        = "String"
  value       = datadog_synthetics_private_location.cdap.id
}
