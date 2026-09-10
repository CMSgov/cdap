# ALB to ECS task (mTLS proxy port)
resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = module.alb.security_group_id
  referenced_security_group_id = module.ecs_service.task_security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy sidecar"
}

# HTTPS ingress — internet-facing ALBs allow from anywhere,
# internal ALBs allow from within the VPC only
resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = module.ecs_service.task_security_group_id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow inbound from ALB to mTLS proxy sidecar"
}
