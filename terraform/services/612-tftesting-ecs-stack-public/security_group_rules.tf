resource "aws_vpc_security_group_ingress_rule" "alb_to_service_a" {
  security_group_id            = module.service_a.task_security_group_id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy sidecar on service_a"
}

# Allow service_a to reach service_b over Service Connect
resource "aws_vpc_security_group_ingress_rule" "service_a_to_service_b" {
  security_group_id            = module.service_b.task_security_group_id
  referenced_security_group_id = module.service_a.task_security_group_id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "Allow service_a to reach service_b via Service Connect"
}

resource "aws_vpc_security_group_egress_rule" "service_a_to_service_b" {
  security_group_id            = module.service_a.task_security_group_id
  referenced_security_group_id = module.service_b.task_security_group_id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "Allow service_a to call service_b via Service Connect"
}
