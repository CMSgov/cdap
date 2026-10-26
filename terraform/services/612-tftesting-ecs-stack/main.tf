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
  platform = module.platform

  domain_name              = local.config.domain.name # null, so will default to "${module.platform.service}"
  enable_internal_endpoint = true
}

# -------------------------------------------------------
# ALB — internal, HTTPS only
# -------------------------------------------------------
module "alb" {
  count  = local.infra_enabled ? 1 : 0
  source = "../../modules/alb"

  platform = module.platform
  internal = true

  acm_certificate_arn        = module.acm_internal[0].private_cert_arn
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
  count                           = local.services_enabled ? 1 : 0
  source                          = "../../modules/service"
  platform                        = merge(module.platform, { service = "ecs-stack-caller" })
  image_tag_service_name_override = "tftesting-service" # override as using image generated in different terraservice
  enable_execute_command          = true

  cluster_arn = data.aws_ecs_cluster.this.arn

  cpu    = local.config.services.caller.cpu
  memory = local.config.services.caller.memory
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
    rollback = local.config.services.caller.deployment_rollback
  }

  # consumes worker over Service Connect; exposes nothing itself
  service_connect_enabled = true
  service_connect         = []

  port_mappings = [
    { name = "http", containerPort = 8080, protocol = "tcp" }
  ]

  enable_alb_integration = true
  alb_listener_arn       = module.alb[0].https_listener_arns["default"]
  alb_security_group_id  = module.alb[0].security_group_id
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
  enable_execute_command = true

  count  = local.services_enabled ? 1 : 0
  source = "../../modules/service"

  platform    = merge(module.platform, { service = "ecs-stack-worker" })
  cluster_arn = data.aws_ecs_cluster.this.arn

  image_tag_service_name_override = "tftesting-service"

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
    rollback = local.config.services.worker.deployment_rollback
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
  count  = (local.config.datadog_synthetics.available && local.services_enabled) ? 1 : 0
  source = "../../modules/datadog_synthetics"

  env    = var.env
  app    = module.platform.app
  notify = "@webhook-slack-${module.platform.app}"

  enabled              = local.config.datadog_synthetics.enabled
  min_failure_duration = local.config.datadog_synthetics.min_failure_duration

  tests = [
    {
      name           = module.platform.service
      subtype        = "http"
      allow_insecure = true

      request_definition = {
        method = "GET"
        url    = "https://${module.alb[0].internal_record}/integration-test"
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
