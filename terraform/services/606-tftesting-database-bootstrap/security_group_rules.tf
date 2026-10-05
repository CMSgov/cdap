resource "aws_vpc_security_group_ingress_rule" "codebuild" {
  count                        = local.tftesting_cluster_exists ? 1 : 0
  security_group_id            = data.aws_ssm_parameter.db_security_group_id[0].value
  referenced_security_group_id = data.aws_ssm_parameter.codebuild_security_group_id.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "codebuild" {
  count                        = local.tftesting_cluster_exists ? 1 : 0
  security_group_id            = data.aws_ssm_parameter.codebuild_security_group_id.value
  referenced_security_group_id = data.aws_ssm_parameter.db_security_group_id[0].value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
