locals {
  config        = yamldecode(file("${path.module}/config/${var.env}.yml"))
  desired_count = try(local.config.ecs.desired_count, 0)
  cluster_name  = try(local.config.ecs.cluster, "cdap-${var.env}")
}

module "acm" {
  source = "../../modules/acm_certificate"

  platform                 = module.platform
  enable_internal_endpoint = true
}

# Create DNS record pointing to the ALB
resource "aws_route53_record" "alb_internal" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "${module.platform.service}.${trimsuffix(data.aws_route53_zone.internal.name, ".")}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

module "alb" {
  source        = "../../modules/alb"
  name_override = "cdap-${var.env}-ecs-int-alb"

  platform                          = module.platform
  internal                          = true                        # will use private subnet
  acm_certificate_arn               = module.acm.private_cert_arn # PACE cert
  enable_http_redirect              = false                       # internal — no HTTP redirect
  enable_datadog_synthetics_ingress = true
}

module "ecs_service" {
  source                          = "../../modules/service"
  image_tag_service_name_override = "tftesting-service"
  desired_count                   = local.desired_count

  cpu    = 256
  memory = 512

  platform    = module.platform
  cluster_arn = data.aws_ecs_cluster.cluster_test.arn

  alb_security_group_id             = module.alb.security_group_id
  alb_listener_arn                  = module.alb.https_listener_arn
  alb_port_name                     = "http"
  enable_alb_integration            = true
  enable_datadog_synthetics_ingress = true

  port_mappings = [
    {
      name          = "http"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }
  ]

  container_environment = [
    { name = "DOWNSTREAM_URL", value = "http://tftesting-service-b:8080/ping" }
  ]
  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 60
    timeout     = 5
  }
}

module "service_b" {
  source = "../../modules/service"

  service_name_override           = "tftesting-service-b"
  image_tag_service_name_override = "tftesting-service" # reuse the same image/tag as service A
  cluster_arn                     = data.aws_ecs_cluster.cluster_test.arn
  cpu                             = 256
  memory                          = 512
  log_retention_days              = 1
  desired_count                   = local.desired_count

  port_mappings = [
    { name = "http", containerPort = 8080, protocol = "tcp", appProtocol = "http" }
  ]
  service_connect_port_name = "http"

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 60 # ddtrace import blocks up to 60s waiting on the Datadog agent
    timeout     = 5
  }

  container_environment = [] # no DOWNSTREAM_URL — this is the responder

  enable_ecs_service_connect        = true
  service_connect_namespace_arn     = data.aws_service_discovery_http_namespace.tftesting.arn
  enable_datadog_synthetics_ingress = true

  platform = module.platform
}
