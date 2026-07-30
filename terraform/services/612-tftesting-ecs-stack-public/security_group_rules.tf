resource "aws_vpc_security_group_ingress_rule" "alb_to_service_a" {
  security_group_id            = module.service_a.task_security_group_id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy sidecar on service_a"
}
