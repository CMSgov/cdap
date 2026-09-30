locals {
  config        = yamldecode(file("${path.module}/config/${var.env}.yml"))
  desired_count = try(local.config.ecs.desired_count, 0)
  cluster_name  = try(local.config.ecs.cluster, "cdap-${var.env}") # 👈 add this
}

resource "tls_private_key" "self_signed" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "self_signed" {
  private_key_pem = tls_private_key.self_signed.private_key_pem

  subject {
    country             = "US"
    province            = "MD"
    locality            = "Rockville"
    organization        = "US Dept of Health and Human Services"
    organizational_unit = "Centers for Medicare and Medicaid Services"
    common_name         = "tftesting.${var.env}.cdap.cms.gov"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

module "acm" {
  source = "../../modules/acm_certificate"

  platform = module.platform

  enable_internal_endpoint = false
  enable_mtls_sidecar      = true

  # Public path — exercises the exact same code as CMS-provided certs
  public_domain_name       = "tftesting.${var.env}.cdap.cms.gov"
  # replace these with a self signed cert
  public_certificate       = tls_self_signed_cert.self_signed.cert_pem
  public_private_key       = tls_private_key.self_signed.private_key_pem
  public_certificate_chain = null # No chain for self-signed
  public_certificate_versions = []
}

module "alb" {
  source        = "../../modules/alb"
  name_override = "cdap-${var.env}-ecs-pub-alb"

  platform                          = module.platform
  internal                          = false
  acm_certificate_arn               = module.acm.public_cert_arn
  enable_http_redirect              = true
  enable_datadog_synthetics_ingress = true
}

module "service_a" {
  source                          = "../../modules/service"
  image_tag_service_name_override = "tftesting-service"
  desired_count                   = local.desired_count
  service_name_override           = "tftesting-a"
  container_environment = [
    {
      name  = "DOWNSTREAM_URL"
      value = "http://tftesting-b:8081/ping" # Service Connect DNS name
    }
  ]

  cpu    = 256
  memory = 512

  enable_ecs_service_connect = true

  platform    = module.platform
  cluster_arn = data.aws_ecs_cluster.cluster_test.arn

  alb_listener_arn       = module.alb.https_listener_arn
  enable_alb_integration = true

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


module "service_b" {
  source                          = "../../modules/service"
  image_tag_service_name_override = "tftesting-service"
  desired_count                   = local.desired_count
  service_name_override           = "tftesting-b"
  enable_ecs_service_connect      = true
  service_connect_namespace_arn = data.aws_service_discovery_http_namespace.tftesting.arn

  # this stack tests a service connection that is not ALB entry
  enable_alb_integration = false
  mtls_cert_arn          = null
  enable_mtls_sidecar    = false

  cpu    = 256
  memory = 512

  platform    = module.platform
  cluster_arn = data.aws_ecs_cluster.cluster_test.arn

  port_mappings = [
    {
      name          = "tftesting-b"
      containerPort = 8081
      hostPort      = 8081
      protocol      = "tcp"
    }
  ]
}
