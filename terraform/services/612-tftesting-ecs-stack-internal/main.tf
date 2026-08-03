locals {
  config        = yamldecode(file("${path.module}/config/${var.env}.yml"))
  desired_count = try(local.config.ecs.desired_count, 0)
  cluster_name  = try(local.config.ecs.cluster, "cdap-${var.env}") # 👈 add this
}

module "acm" {
  source = "../../modules/acm_certificate"

  platform                 = module.platform
  enable_internal_endpoint = true
  enable_mtls_sidecar      = true
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

  platform             = module.platform
  internal             = true                        # will use private subnet
  acm_certificate_arn  = module.acm.private_cert_arn # PACE cert
  enable_http_redirect = false                       # internal — no HTTP redirect
}

module "ecs_service" {
  source                          = "../../modules/service"
  image_tag_service_name_override = "tftesting-service"
  desired_count                   = local.desired_count

  cpu    = 256
  memory = 512

  platform    = module.platform
  cluster_arn = data.aws_ecs_cluster.cluster_test.arn

  alb_listener_arn       = module.alb.https_listener_arn
  enable_alb_integration = true
  mtls_domain            = module.acm.mtls_domain

  mtls_cert_arn       = module.acm.private_cert_arn
  enable_mtls_sidecar = true
  port_mappings = [
    {
      name          = "http"
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }
  ]
}

