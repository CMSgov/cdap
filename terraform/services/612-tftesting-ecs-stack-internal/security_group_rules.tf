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

resource "aws_vpc_security_group_egress_rule" "service_a_to_service_b" {
  security_group_id            = module.ecs_service.task_security_group_id
  referenced_security_group_id = module.service_b.task_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow tftesting-a to reach tftesting-b via Service Connect"
}

resource "aws_vpc_security_group_ingress_rule" "service_b_from_service_a" {
  security_group_id            = module.service_b.task_security_group_id
  referenced_security_group_id = module.ecs_service.task_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow tftesting-b to receive from tftesting-a via Service Connect"
}

