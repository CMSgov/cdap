locals {
  config      = yamldecode(file("${path.module}/config/${var.env}.yml"))
  ecs_enabled = var.ecs_enabled != null ? var.ecs_enabled : try(local.config.ecs.enabled, true)
}

data "aws_ecs_cluster" "cluster_test" {
  cluster_name = "cdap-${var.env}"
}

module "service_test_service" {
  source               = "../../modules/service/"
  enable_datadog_agent = true
  log_retention_days   = 30

  cluster_arn = data.aws_ecs_cluster.cluster_test.arn
  cpu         = 512
  memory      = 1024


  health_check = {
    command     = ["CMD-SHELL", "pgrep -f ddtrace-run || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 30
    timeout     = 5
  }

  desired_count        = 1
  force_new_deployment = true

  enable_ecs_service_connect = false

  deployment_circuit_breaker = {
    enable   = true
    rollback = false
  }

  platform = module.platform
}
