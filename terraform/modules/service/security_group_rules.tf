# -------------------------------------------------------
# Use VPC Gateway and Interface Endpoints
# -------------------------------------------------------
data "aws_security_group" "endpoints" {
  name   = "${var.platform.vpc_name}-vpce-endpoints"
  vpc_id = var.platform.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "to_endpoints" {
  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_security_group.endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Interface endpoints (SSM, KMS, Secrets Manager, logs, STS, ECR, SQS, SNS)"
}

data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${var.platform.primary_region.name}.s3"
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  count             = var.needs_s3_access ? 1 : 0
  security_group_id = aws_security_group.task[0].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "S3 via gateway endpoint"
}

# -------------------------------------------------------
# Allow Datadog Synthetics 
# -------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "datadog_synthetics" {
  count                        = (var.enable_datadog_synthetics_ingress && length(var.security_groups) == 0) ? 1 : 0
  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from Datadog private location synthetic test runner"
}

# -------------------------------------------------------
# Task SG ingress from ALB
# -------------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "alb_to_proxy" {
  count = (
    local.enable_mtls_sidecar &&
    local.enable_alb_integration &&
    length(var.security_groups) == 0 &&
    var.alb_security_group_id != null
  ) ? 1 : 0

  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = var.proxy_listen_port
  to_port                      = var.proxy_listen_port
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy on port ${var.proxy_listen_port}"
}

resource "aws_vpc_security_group_ingress_rule" "alb_to_health" {
  count = (
    local.enable_mtls_sidecar &&
    local.enable_alb_integration &&
    length(var.security_groups) == 0 &&
    var.alb_security_group_id != null
  ) ? 1 : 0

  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = var.proxy_healthcheck_port
  to_port                      = var.proxy_healthcheck_port
  ip_protocol                  = "tcp"
  description                  = "Allow ALB health check to reach proxy health port ${var.proxy_healthcheck_port}"
}

# -------------------------------------------------------
# ALB SG egress to task
# -------------------------------------------------------
resource "aws_vpc_security_group_egress_rule" "alb_to_task_proxy" {
  count = (
    local.enable_mtls_sidecar &&
    local.enable_alb_integration &&
    var.alb_security_group_id != null
  ) ? 1 : 0

  security_group_id            = var.alb_security_group_id
  referenced_security_group_id = aws_security_group.task[0].id
  from_port                    = var.proxy_listen_port
  to_port                      = var.proxy_listen_port
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy on port ${var.proxy_listen_port}"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task_health" {
  count = (
    local.enable_mtls_sidecar &&
    local.enable_alb_integration &&
    var.alb_security_group_id != null
  ) ? 1 : 0

  security_group_id            = var.alb_security_group_id
  referenced_security_group_id = aws_security_group.task[0].id
  from_port                    = var.proxy_healthcheck_port
  to_port                      = var.proxy_healthcheck_port
  ip_protocol                  = "tcp"
  description                  = "Allow ALB health check to reach proxy health port ${var.proxy_healthcheck_port}"
}

# -------------------------------------------------------
# Datadog synthetics ingress to task containers
# Allows Datadog private location to reach container ports
# directly — independent of ALB target group association
# -------------------------------------------------------

# Non-mTLS services — allow Datadog to reach app container ports
resource "aws_vpc_security_group_ingress_rule" "datadog_to_app" {
  for_each = (
    var.enable_datadog_synthetics_ingress &&
    length(var.security_groups) == 0 &&
    !nonsensitive(local.enable_mtls_sidecar)
    ) ? {
    for pm in coalesce(var.port_mappings, []) :
    pm.name => pm.containerPort
    if pm.containerPort != null
  } : {}

  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
  description                  = "Allow Datadog synthetics to reach ${each.key} port ${each.value}"
}

# mTLS services — allow Datadog to reach proxy port and health port
resource "aws_vpc_security_group_ingress_rule" "datadog_to_proxy" {
  count = (
    local.enable_mtls_sidecar &&
    length(var.security_groups) == 0 &&
    var.enable_datadog_synthetics_ingress
  ) ? 1 : 0

  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  from_port                    = var.proxy_listen_port
  to_port                      = var.proxy_listen_port
  ip_protocol                  = "tcp"
  description                  = "Allow Datadog synthetics to reach mTLS proxy on port ${var.proxy_listen_port}"
}

resource "aws_vpc_security_group_ingress_rule" "datadog_to_health" {
  count = (
    local.enable_mtls_sidecar &&
    length(var.security_groups) == 0 &&
    var.enable_datadog_synthetics_ingress
  ) ? 1 : 0

  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  from_port                    = var.proxy_healthcheck_port
  to_port                      = var.proxy_healthcheck_port
  ip_protocol                  = "tcp"
  description                  = "Allow Datadog synthetics to reach proxy health port ${var.proxy_healthcheck_port}"
}
