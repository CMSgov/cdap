# ALB to target service
resource "aws_vpc_security_group_egress_rule" "alb_to_target" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.lb[0].alb_security_group_id
  referenced_security_group_id = module.service_target[0].task_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "ALB to target service, port 8080"
}

resource "aws_vpc_security_group_ingress_rule" "target_from_alb" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.service_target[0].task_security_group_id
  referenced_security_group_id = module.lb[0].alb_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  description                  = "ALB to target service, port 8080"
}

# Consumer to PrivateLink endpoint
resource "aws_vpc_security_group_egress_rule" "consumer_to_endpoint" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.service_consumer[0].task_security_group_id
  referenced_security_group_id = module.privatelink_endpoint[0].security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Consumer to PrivateLink endpoint, port 443"
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_consumer" {
  count                        = local.services_enabled ? 1 : 0
  security_group_id            = module.privatelink_endpoint[0].security_group_id
  referenced_security_group_id = module.service_consumer[0].task_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Consumer to PrivateLink endpoint, port 443"
}

