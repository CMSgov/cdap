resource "aws_vpc_security_group_egress_rule" "alb_to_caller" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.alb[0].security_group_id
  referenced_security_group_id = module.service_caller[0].task_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "ALB to caller service, port 8080"
}

resource "aws_vpc_security_group_egress_rule" "caller_to_worker" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.service_caller[0].task_security_group_id
  referenced_security_group_id = module.service_worker[0].task_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Caller to worker via Service Connect, port 8080"
}

resource "aws_vpc_security_group_ingress_rule" "worker_from_caller" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.service_worker[0].task_security_group_id
  referenced_security_group_id = module.service_caller[0].task_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "Caller to worker via Service Connect, port 8080"
}
