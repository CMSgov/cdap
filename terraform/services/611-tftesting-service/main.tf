locals {
  config        = yamldecode(file("${path.module}/config/${var.env}.yml"))
  desired_count = try(local.config.ecs.desired_count, 0)
  cluster_name  = try(local.config.ecs.cluster, "cdap-${var.env}") # 👈 add this
}

data "aws_ecs_cluster" "cluster_test" {
  cluster_name = local.cluster_name
}

module "tftesting_service" {
  source               = "../../modules/service/"
  desired_count        = local.desired_count
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

  force_new_deployment = true

  enable_ecs_service_connect = false

  deployment_circuit_breaker = {
    enable   = true
    rollback = false
  }

  platform = module.platform
}
