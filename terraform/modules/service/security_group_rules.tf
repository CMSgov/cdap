
resource "aws_vpc_security_group_egress_rule" "https" {
  count             = (length(var.security_groups) == 0) ? 1 : 0
  security_group_id = aws_security_group.task[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow HTTPS outbound (ECR, CloudWatch, SSM)"
}

resource "aws_vpc_security_group_ingress_rule" "datadog_synthetics" {
  count                        = (var.enable_datadog_synthetics_ingress && length(var.security_groups) == 0) ? 1 : 0
  security_group_id            = aws_security_group.task[0].id
  referenced_security_group_id = data.aws_ssm_parameter.datadog_private_location_sg[0].value
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from Datadog private location synthetic test runner"
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
    !local.enable_alb_integration &&
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
    !local.enable_alb_integration &&
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
    !local.enable_alb_integration &&
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
