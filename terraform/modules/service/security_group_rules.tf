# -------------------------------------------------------
# Task SG ingress from ALB — auto-managed when mTLS + ALB enabled
# Module only manages rules on the task SG it owns
# ALB egress rules remain in the terraservice security_group_rules.tf
# -------------------------------------------------------
# resource "aws_vpc_security_group_ingress_rule" "alb_to_proxy" {
#   count = (
#     local.enable_mtls_sidecar &&
#     local.enable_alb_integration &&
#     length(var.security_groups) == 0 &&
#     var.alb_security_group_id != null
#   ) ? 1 : 0
#
#   security_group_id            = aws_security_group.task[0].id
#   referenced_security_group_id = var.alb_security_group_id
#   from_port                    = var.proxy_listen_port
#   to_port                      = var.proxy_listen_port
#   ip_protocol                  = "tcp"
#   description                  = "Allow ALB to reach mTLS proxy on port ${var.proxy_listen_port}"
# }
#
# resource "aws_vpc_security_group_ingress_rule" "alb_to_health" {
#   count = (
#     local.enable_mtls_sidecar &&
#     local.enable_alb_integration &&
#     length(var.security_groups) == 0 &&
#     var.alb_security_group_id != null
#   ) ? 1 : 0
#
#   security_group_id            = aws_security_group.task[0].id
#   referenced_security_group_id = var.alb_security_group_id
#   from_port                    = var.proxy_healthcheck_port
#   to_port                      = var.proxy_healthcheck_port
#   ip_protocol                  = "tcp"
#   description                  = "Allow ALB health check to reach proxy health port ${var.proxy_healthcheck_port}"
# }
