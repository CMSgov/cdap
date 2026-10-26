data "aws_ecs_cluster" "this" {
  cluster_name = local.config.ecs.cluster
}

# -------------------------------------------------------
# ACM — internal endpoint only, used by the ALB
# -------------------------------------------------------
module "acm_internal" {
  count  = local.infra_enabled ? 1 : 0
  source = "../../modules/acm_certificate_private"

  # distinct platform.service so this doesn't collide with your existing
  # single-service tftesting terraservice's naming
  platform = merge(module.platform, { service = "ecs-stack" })

  domain_name              = local.config.domain.name # null, so will default to "ecs-stack"
  enable_internal_endpoint = true
}

# -------------------------------------------------------
# ALB — internal, HTTPS only
# -------------------------------------------------------
module "alb" {
  count  = local.infra_enabled ? 1 : 0
  source = "../../modules/alb"

  platform = merge(module.platform, { service = "ecs-stack" })
  internal = true

  acm_certificate_arn = module.acm_internal[0].private_cert_arn
  create_internal_dns_record = true 

  enable_datadog_synthetics_ingress = local.config.datadog_synthetics.enabled

  https_listeners = {
    default = {
      certificate_arn                    = module.acm_internal[0].private_cert_arn
      default_action_type                = "fixed-response"
      default_fixed_response_status_code = 404
    }
  }
}

# -------------------------------------------------------
# ECS Service A ("caller"), behind the ALB, calls worker via Service Connect
# -------------------------------------------------------
module "service_caller" {
  count  = local.services_enabled ? 1 : 0
  source = "../../modules/service"

  platform    = merge(module.platform, { service = "caller" })
  cluster_arn = data.aws_ecs_cluster.this.arn

  # shared test image lives under a different service name in ECR/SSM
  image_tag_service_name_override = "tftesting-service" # TODO confirm this matches your existing repo/SSM naming

  cpu    = local.config.services.caller.cpu
  memory = local.config.services.caller.memory

  port_mappings = [
    { name = "http", containerPort = 8080, protocol = "tcp" }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 30
    timeout     = 5
  }

  enable_datadog_agent = true
  log_retention_days   = 30
  force_new_deployment = true

  deployment_circuit_breaker = {
    enable   = true
    rollback = false
  }

  # consumes worker over Service Connect; exposes nothing itself
  service_connect_enabled = true
  service_connect         = []

  enable_alb_integration = true
  alb_listener_arn       = module.alb[0].https_listener_arns["default"]
  alb_port_name          = "http"
  alb_priority           = 100
  alb_path_patterns      = ["/*"]
  alb_health_check = {
    path = "/health"
  }

  container_environment = [
    { name = "DOWNSTREAM_URL", value = "http://worker:8080/ping" },
  ]
}

# -------------------------------------------------------
# ECS Service B ("worker"), no ALB, reachable only via Service Connect
# -------------------------------------------------------
module "service_worker" {
  count  = local.services_enabled ? 1 : 0
  source = "../../modules/service"

  platform    = merge(module.platform, { service = "worker" })
  cluster_arn = data.aws_ecs_cluster.this.arn

  image_tag_service_name_override = "tftesting-service" # TODO same as above

  cpu    = local.config.services.worker.cpu
  memory = local.config.services.worker.memory

  port_mappings = [
    { name = "worker", containerPort = 8080, protocol = "tcp" }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 30
    timeout     = 5
  }

  enable_datadog_agent = true
  log_retention_days   = 30
  force_new_deployment = true

  deployment_circuit_breaker = {
    enable   = true
    rollback = false
  }

  service_connect_enabled = true
  service_connect = [
    { port = 8080, port_name = "worker" }
  ]

  container_environment = [
    { name = "RANDOM_TEST", value = "env-var" },
  ]
}

# -------------------------------------------------------
# Datadog synthetic — gated on config, hits the ALB-fronted caller
# -------------------------------------------------------
module "datadog_synthetics" {
  count  = (local.config.datadog_synthetics.enabled && local.services_enabled) ? 1 : 0
  source = "../../modules/datadog_synthetics"

  env    = var.env
  app    = module.platform.app
  notify = "@webhook-slack-${module.platform.app}"

  enabled              = local.config.datadog_synthetics.enabled
  min_failure_duration = local.config.datadog_synthetics.min_failure_duration

  tests = [
    {
      name    = "cdap-${module.platform.env}-ecs-stack-service-connect"
      subtype = "http"
    request_definition = {
        method = "GET"
        url    = "https://ecs-stack.${module.platform.env}.${module.platform.app}.internal.cms.gov/integration-test"
    }
      assertions = [
        { type = "statusCode", operator = "is", target = "200" },
        {
          type     = "body"
          operator = "validatesJSONPath"
          targetjsonpath = {
            jsonpath    = "$.status"
            operator    = "is"
            targetvalue = "ok"
          }
        }
      ]
      tick_every           = local.config.datadog_synthetics.tick_every
      min_failure_duration = local.config.datadog_synthetics.min_failure_duration
    }
  ]
}
