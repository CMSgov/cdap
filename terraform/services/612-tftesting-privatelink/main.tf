data "aws_ecs_cluster" "this" {
  cluster_name = "cdap-${var.env}-tftesting"
}

# -----------------------------------------------------
# Consumer Side 
# -----------------------------------------------------
# -----------------------------------------------------
# PrivateLink interface endpoint
# All in CDAP VPC for this test; reachability
# depends entirely on the ingress, not on
# normal VPC routing, since there is no internal DNS record
# and nothing else admits traffic to the ALB/NLB.
# -----------------------------------------------------

module "privatelink_endpoint" {
  count  = local.services_enabled ? 1 : 0
  source = "../../modules/privatelink_endpoint"

  dns_record_name    = "tftesting-endpoint"
  platform           = module.platform
  ssm_parameter_name = "/${module.platform.app}/${module.platform.env}/privatelink-target/privatelink" # This should reference the other app and its named service being consumed 
  target_domain_name = module.acm_internal[0].internal_domain                                          # this can be constructed predictably as ${target_service}.${var.platform.env}.${target_app}.internal.cms.gov

  depends_on = [module.lb] # the target side privatelink service has to exist before the consumer can set up an endpoint, no circular dependency if the principal granted access to endpoint service is broad 
}

# -----------------------------------------------------
# Consumer service — calls the target through the
# PrivateLink endpoint's AWS-generated DNS name.
# -----------------------------------------------------
module "service_consumer" {
  count                           = local.services_enabled ? 1 : 0
  source                          = "../../modules/service"
  platform                        = merge(module.platform, { service = "privatelink-consumer" })
  image_tag_service_name_override = "tftesting-service"
  enable_execute_command          = true

  cluster_arn = data.aws_ecs_cluster.this.arn

  cpu    = local.config.services.consumer.cpu
  memory = local.config.services.consumer.memory

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
    rollback = local.config.services.consumer.deployment_rollback
  }

  service_connect_enabled = false

  port_mappings = [
    { name = "http", containerPort = 8080, protocol = "tcp" }
  ]

  container_environment = [
    {
      name  = "DOWNSTREAM_URL"
      value = "https://${module.privatelink_endpoint[0].friendly_dns_name}/ping"
    },
  ]
}


# Receiver

module "acm_internal" {
  count  = local.infra_enabled ? 1 : 0
  source = "../../modules/acm_certificate_private"

  platform = module.platform

  domain_name            = local.config.domain.name                        # null, so defaults to "${module.platform.service}"
  enrolled_upstream_apps = local.config.privatelink.enrolled_upstream_apps # using this as an example to prove the SANS usage 
}


module "lb" {
  count  = local.infra_enabled ? 1 : 0
  source = "../../modules/lb"

  platform = module.platform
  internal = true

  acm_certificate_arn        = module.acm_internal[0].private_cert_arn
  private_record_name        = module.acm_internal[0].internal_domain
  create_internal_dns_record = false # reachable only via the PrivateLink path, by design

  https_listeners = {
    default = {
      certificate_arn = module.acm_internal[0].private_cert_arn
    }
  }

  create_nlb                    = true
  nlb_mode                      = "front_alb"
  enable_privatelink            = true
  privatelink_target_port       = 443
  privatelink_health_check_path = "/health"
  privatelink_private_dns_name  = null # internal.cms.gov won't pass public-DNS verification
}

# -----------------------------------------------------
# Target service — fronted by ALB --> NLB --> PrivateLink.
# -----------------------------------------------------
module "service_target" {
  count                           = local.services_enabled ? 1 : 0
  source                          = "../../modules/service"
  platform                        = merge(module.platform, { service = "privatelink-target" })
  image_tag_service_name_override = "tftesting-service"
  enable_execute_command          = true

  cluster_arn = data.aws_ecs_cluster.this.arn

  cpu    = local.config.services.target.cpu
  memory = local.config.services.target.memory

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
    rollback = local.config.services.target.deployment_rollback
  }

  service_connect_enabled = false

  port_mappings = [
    { name = "http", containerPort = 8080, protocol = "tcp" }
  ]

  enable_alb_integration = true
  alb_listener_arn       = module.lb[0].https_listener_arns["default"]
  alb_security_group_id  = module.lb[0].alb_security_group_id
  alb_port_name          = "http"
  alb_priority           = 100
  alb_path_patterns      = ["/*"]
  alb_health_check = {
    path = "/health"
  }
}
