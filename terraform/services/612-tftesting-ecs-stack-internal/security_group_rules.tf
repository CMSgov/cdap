# ALB to ECS task (mTLS proxy port)
resource "aws_vpc_security_group_egress_rule" "alb_to_task_proxy" {
  security_group_id            = module.alb.security_group_id
  referenced_security_group_id = module.ecs_service.task_security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow ALB to reach mTLS proxy sidecar"
}

# ALB to ECS task (plain HTTP health check port)
resource "aws_vpc_security_group_egress_rule" "alb_to_task_health" {
  security_group_id            = module.alb.security_group_id
  referenced_security_group_id = module.ecs_service.task_security_group_id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "Allow ALB health check to reach proxy health port"
}

# Task ingress from ALB (mTLS proxy port)
resource "aws_vpc_security_group_ingress_rule" "task_from_alb_proxy" {
  security_group_id            = module.ecs_service.task_security_group_id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  description                  = "Allow inbound from ALB to mTLS proxy sidecar"
}

# Task ingress from ALB (plain HTTP health check port)
resource "aws_vpc_security_group_ingress_rule" "task_from_alb_health" {
  security_group_id            = module.ecs_service.task_security_group_id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "Allow inbound from ALB health check to proxy health port"
}