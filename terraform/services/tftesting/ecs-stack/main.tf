locals {
  default_tags               = module.platform.default_tags
  network_access_logs_bucket = module.platform.splunk_logging_bucket.bucket
}

module "platform" {
  source    = "../../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = "test"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tftesting/service"
  service     = "tftesting"
}

# # -------------------------------------------------------
# # ALB test with internal, using private cert
# # -------------------------------------------------------
# module "alb" {
#   source = "../../../modules/alb"
#
#   platform = {
#     app     = module.platform.app
#     env     = module.platform.env
#     service = "tftesting"
#
#     primary_region  = { name = module.platform.primary_region.name }
#     private_subnets = module.platform.private_subnets
#     vpc_id          = module.platform.vpc_id
#   }
#
#   internal            = true
#   acm_certificate_arn = module.acm_certificate.private_cert_arn
#   security_group_ids  = [aws_security_group.alb.id]
#
#   enable_http_redirect = true
# }
#

#

# # -------------------------------------------------------
# # ACM Certificate test with private cert
# # -------------------------------------------------------
#
# module "acm_certificate" {
#   source = "../../../modules/acm_certificate"
#
#   platform = {
#     app     = module.platform.app
#     env     = module.platform.env
#     service = "tftesting"
#
#     kms_alias_primary = {
#       target_key_arn = module.platform.kms_alias_primary.target_key_arn
#     }
#
#     primary_region = {
#       name = module.platform.primary_region.name
#     }
#
#     private_subnets = module.platform.private_subnets
#     vpc_id          = module.platform.vpc_id
#   }
#
#   # Testing private cert only
#   enable_internal_endpoint = true
#   enable_zscaler_endpoint  = false
#   public_domain_name = null
# }


# -------------------------------------------------------
# Cluster
# -------------------------------------------------------
resource "aws_ecs_cluster" "test" {
  name = "cdap-test-tftesting-cluster"

  # Service Connect requires a default namespace on the cluster
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.test.arn
  }
}

# -------------------------------------------------------
# Cloud Map Namespace (required for Service Connect)
# -------------------------------------------------------
resource "aws_service_discovery_http_namespace" "test" {
  name        = "cdap-test-tftesting.cmscloud.local"
  description = "Service Connect namespace for ECS module testing"
}

# -------------------------------------------------------
# ECS Service Module
# -------------------------------------------------------
module "service_a" {
  enable_datadog_agent = true
  log_retention_days   = 1
  source               = "../../../modules/service/"
  # Use this service to test connections to service-b through service connect
  enable_execute_command = true

  additional_task_role_policies = {
    ecs_exec = aws_iam_policy.ecs_exec.arn
  }
  mount_points = [
    { containerPath = "/var/cache/nginx", sourceVolume = "nginx_cache", readOnly = false },
    { containerPath = "/var/run", sourceVolume = "nginx_run", readOnly = false },
    { containerPath = "/tmp", sourceVolume = "tmp", readOnly = false },
    { containerPath = "/var/lib/amazon/ssm", sourceVolume = "ssm_agent", readOnly = false }
  ]

  volumes = [
    { name = "nginx_cache", configure_at_launch = false },
    { name = "nginx_run", configure_at_launch = false },
    { name = "tmp", configure_at_launch = false },
    { name = "ssm_agent", configure_at_launch = false }
  ]

  cluster_arn = aws_ecs_cluster.test.arn
  image       = "public.ecr.aws/nginx/nginx:latest"
  cpu         = 256
  memory      = 512

  port_mappings = [
    {
      name          = "http"
      containerPort = 80
      protocol      = "tcp"
      appProtocol   = "http"
    }
  ]
  service_connect_port_name = "http"
  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 15
    timeout     = 5
  }

  desired_count         = 1
  force_new_deployment  = false
  container_environment = []
  container_secrets     = []

  # -------------------------------------------------------
  # ALB Testing
  # -------------------------------------------------------

  #   alb_listener_arn  = module.alb.https_listener_arn
  #   alb_port_name     = "http"
  #   alb_path_patterns = ["/*"]
  #   alb_priority      = 100
  # -------------------------------------------------------
  # Service Connect Testing
  # -------------------------------------------------------
  enable_ecs_service_connect = true
  service_connect_namespace  = aws_service_discovery_http_namespace.test
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  # -------------------------------------------------------
  # Platform — passed through from your platform module
  # -------------------------------------------------------
  platform = {
    app     = module.platform.app
    env     = module.platform.env
    service = "tftesting-a"

    kms_alias_primary = {
      target_key_arn = module.platform.kms_alias_primary.target_key_arn
    }

    primary_region = {
      name = module.platform.primary_region.name
    }

    private_subnets = module.platform.private_subnets
    vpc_id          = module.platform.vpc_id
    account_id      = module.platform.aws_caller_identity.account_id
  }
}

module "service_b" {
  log_retention_days = 1
  source             = "../../../modules/service/"

  # -------------------------------------------------------
  # Platform — passed through from your platform module
  # -------------------------------------------------------
  platform = {
    app     = module.platform.app
    env     = module.platform.env
    service = "tftesting-b"

    kms_alias_primary = {
      target_key_arn = module.platform.kms_alias_primary.target_key_arn
    }

    primary_region = {
      name = module.platform.primary_region.name
    }

    private_subnets = module.platform.private_subnets
    vpc_id          = module.platform.vpc_id
    account_id      = module.platform.aws_caller_identity.account_id
  }

  cluster_arn = aws_ecs_cluster.test.arn

  mount_points = [
    { containerPath = "/var/cache/nginx", sourceVolume = "nginx_cache", readOnly = false },
    { containerPath = "/var/run", sourceVolume = "nginx_run", readOnly = false },
    { containerPath = "/tmp", sourceVolume = "tmp", readOnly = false }
  ]

  volumes = [
    { name = "nginx_cache", configure_at_launch = false },
    { name = "nginx_run", configure_at_launch = false },
    { name = "tmp", configure_at_launch = false }
  ]

  image  = "public.ecr.aws/nginx/nginx:latest"
  cpu    = 256
  memory = 512

  port_mappings = [
    {
      name          = "http"
      containerPort = 80
      protocol      = "tcp"
      appProtocol   = "http"
    }
  ]
  service_connect_port_name = "http"
  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:80/ || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 15
    timeout     = 5
  }

  desired_count         = 1
  force_new_deployment  = false
  container_environment = []
  container_secrets     = []

  # -------------------------------------------------------
  # Service Connect Testing
  # -------------------------------------------------------
  enable_ecs_service_connect = true
  service_connect_namespace  = aws_service_discovery_http_namespace.test
  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }
}

# Legacy testing ; use this to test legacy compatibility with services not yet on service connect
# -------------------------------------------------------
# Old-style target group — created externally by the caller
# (this is what existing callers like ab2d manage themselves)
# -------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "cdap-test-tftesting-alb-sg"
  description = "Allow HTTPS inbound to ALB"
  vpc_id      = module.platform.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.platform.platform_cidr]
  }

  ingress {
    description = "HTTP from VPC (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.platform.platform_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "legacy_test" {
  name        = "cdap-test-tftesting-legacy-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = module.platform.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "cdap-test-tftesting-legacy-tg"
  }
}

##
# APM Testing
##

module "service_apm" {
  enable_datadog_agent   = true
  log_retention_days     = 1
  source                 = "../../../modules/service/"
  enable_execute_command = true
  mount_points = [
    { containerPath = "/tmp", sourceVolume = "tmp", readOnly = false }
  ]

  volumes = [
    { name = "tmp", configure_at_launch = false }
  ]

  cluster_arn = aws_ecs_cluster.test.arn
  image       = "public.ecr.aws/docker/library/python:3.11-slim"
  cpu         = 256
  memory      = 512
  command = [
    "/bin/sh",
    "-c",
    "pip install -q --target=/tmp/packages ddtrace flask && PYTHONPATH=/tmp/packages /tmp/packages/bin/ddtrace-run python -c \"from flask import Flask; app = Flask(__name__); app.add_url_rule('/', 'index', lambda: ('APM Test OK', 200)); app.add_url_rule('/health', 'health', lambda: ('OK', 200)); app.run(host='0.0.0.0', port=8080)\""
  ]


  port_mappings = [
    {
      name          = "http"
      containerPort = 8080
      protocol      = "tcp"
      appProtocol   = "http"
    }
  ]

  service_connect_port_name = "http"

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 60
    timeout     = 5
  }

  desired_count        = 1
  force_new_deployment = true

  container_environment = [
    { name = "PYTHONPATH", value = "/tmp/packages" }
  ]

  container_secrets = []

  # Still on the same namespace so service_a can reach it via service connect
  enable_ecs_service_connect = true
  service_connect_namespace  = aws_service_discovery_http_namespace.test

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  platform = {
    app     = module.platform.app
    env     = module.platform.env
    service = "tftesting-apm"

    kms_alias_primary = {
      target_key_arn = module.platform.kms_alias_primary.target_key_arn
    }
    primary_region = {
      name = module.platform.primary_region.name
    }
    private_subnets = module.platform.private_subnets
    vpc_id          = module.platform.vpc_id
    account_id      = module.platform.aws_caller_identity.account_id
  }
}


# -------------------------------------------------------
# Backwards compatibility test — uses load_balancers, not alb_listener_arn
# -------------------------------------------------------
module "service_legacy" {
  log_retention_days = 1
  source             = "../../../modules/service/"

  platform = {
    app     = module.platform.app
    env     = module.platform.env
    service = "tftesting-legacy"

    kms_alias_primary = {
      target_key_arn = module.platform.kms_alias_primary.target_key_arn
    }

    primary_region  = { name = module.platform.primary_region.name }
    private_subnets = module.platform.private_subnets
    vpc_id          = module.platform.vpc_id
    account_id      = module.platform.aws_caller_identity.account_id
  }

  cluster_arn = aws_ecs_cluster.test.arn

  image  = "public.ecr.aws/nginx/nginx:latest"
  cpu    = 256
  memory = 512

  mount_points = [
    { containerPath = "/var/cache/nginx", sourceVolume = "nginx_cache", readOnly = false },
    { containerPath = "/var/run", sourceVolume = "nginx_run", readOnly = false },
    { containerPath = "/tmp", sourceVolume = "tmp", readOnly = false }
  ]

  volumes = [
    { name = "nginx_cache", configure_at_launch = false },
    { name = "nginx_run", configure_at_launch = false },
    { name = "tmp", configure_at_launch = false }
  ]

  # Old-style: no name on port mapping — exactly as existing callers pass it
  port_mappings = [
    {
      containerPort = 8081
      protocol      = "tcp"
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8081/ || exit 1"]
    interval    = 30
    retries     = 3
    startPeriod = 15
    timeout     = 5
  }

  security_groups = [aws_security_group.ecs_task.id]

  desired_count        = 1
  force_new_deployment = false

  container_environment = []
  container_secrets     = []

  # -------------------------------------------------------
  # OLD INTERFACE — load_balancers passed directly
  # alb_listener_arn is NOT set, so enable_alb_integration = false
  # local.use_external_load_balancers = true → old dynamic block fires
  # -------------------------------------------------------
  load_balancers = [
    {
      target_group_arn = aws_lb_target_group.legacy_test.arn
      container_name   = "tftesting-legacy"
      container_port   = 8081
    }
  ]

  # No alb_listener_arn, no alb_port_name, no alb_path_patterns
  # No Service Connect for this one — keep it simple
  enable_ecs_service_connect = false

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.legacy_test,
  ]
}

resource "aws_lb" "legacy_test" {
  name                       = "cdap-test-tftesting-legacy-alb"
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = [for s in module.platform.private_subnets : s.id]
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true

  access_logs {
    bucket  = local.network_access_logs_bucket
    enabled = true
  }
}

resource "aws_lb_listener" "legacy_test" {
  load_balancer_arn = aws_lb.legacy_test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.legacy_test.arn
  }
}

# -------------------------------------------------------
# Security Group — sourcing vpc_id from platform module
# -------------------------------------------------------
resource "aws_security_group" "ecs_task" {
  name        = "cdap-test-tftesting-ecs-module-sg"
  description = "Allow inbound HTTP for ECS task test"
  vpc_id      = module.platform.vpc_id #

  ingress {
    description = "HTTP inbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.platform.platform_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
