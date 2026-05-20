# Enable service connect

resource "aws_vpc_security_group_egress_rule" "service_a_to_service_b" {
  security_group_id            = module.service_a.task_security_group_id
  from_port                    = module.service_b.service_connect_port
  to_port                      = module.service_b.service_connect_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.service_b.task_security_group_id
  description                  = "Allow outbound HTTP to service-b (through Service Connect)"
}

resource "aws_vpc_security_group_ingress_rule" "service_b_from_service_a" {
  security_group_id            = module.service_b.task_security_group_id
  from_port                    = module.service_b.service_connect_port
  to_port                      = module.service_b.service_connect_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.service_a.task_security_group_id
  description                  = "Allow inbound HTTP from service-a (Service Connect)"
}

# Enable ALB to ECS TLS
# resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
#   from_port                = 8080
#   to_port                  = 8080
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.ecs_task.id
#   source_security_group_id = aws_security_group.alb.id
#   description              = "Allow inbound from ALB"
# }
