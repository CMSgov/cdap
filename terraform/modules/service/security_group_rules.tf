
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

resource "aws_vpc_security_group_ingress_rule" "datadog_to_app" {
  for_each = (
    var.enable_datadog_synthetics_ingress &&
    length(var.security_groups) == 0
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