##
# Cluster
##
module "cdap_cluster" {
  # TODO set commit hash for version
  source                = "../../modules/cluster"
  platform              = module.platform
  cluster_name_override = "${module.platform.app}-${module.platform.env}-datadog"
}

##
# Service
###
module "ecs_datadog_synthetics" {
  # TODO set commit hash for version
  source = "../../modules/service"
  #source                   = "github.com/CMSgov/cdap//terraform/modules/service?ref=49d3147bdcfd0cb3847bfccc6a883d33d017be3d"
  cluster_arn              = module.cdap_cluster.this.arn
  readonly_root_filesystem = false # Write permission required by Datadog private location worker

  platform = module.platform

  image            = "datadog/synthetics-private-location-worker:1.68.0"
  cpu              = 512
  memory           = 1024
  cpu_architecture = "X86_64" # Datadog worker image is x86 only — do not use ARM64
  desired_count    = 1

  container_secrets = [
    {
      name      = "DATADOG_ACCESS_KEY",
      valueFrom = module.platform.ssm.dd_pl_sensitive.private_location_config_access_key.arn
    },
    {
      name      = "DATADOG_API_KEY",
      valueFrom = module.platform.ssm.datadog.api_key.arn
    },
    {
      name      = "DATADOG_PUBLIC_KEY_PEM",
      valueFrom = module.platform.ssm.dd_pl_sensitive.private_location_config_public_key_pem.arn
    },
    {
      name      = "DATADOG_PRIVATE_KEY",
      valueFrom = module.platform.ssm.dd_pl_sensitive.private_location_config_private_key.arn
    },
    {
      name      = "DATADOG_SECRET_ACCESS_KEY",
      valueFrom = module.platform.ssm.dd_pl_sensitive.private_location_config_secret_access_key.arn
    },
    {
      name      = "DATADOG_SITE",
      valueFrom = module.platform.ssm.dd_pl_nonsensitive.private_location_config_site.arn
    }
  ]

  container_environment = [
    {
      name  = "LOG_LEVEL"
      value = "info"
    },
    {
      name  = "DATADOG_WORKER_ENABLE_STATUS_PROBES"
      value = "true"
    }

  ]

  health_check = {
    command     = ["CMD", "wget", "-O", "/dev/null", "-q", "http://localhost:8080/liveness"]
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
