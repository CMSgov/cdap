resource "aws_security_group" "mount_targets" {
  name        = "${local.full_name}-mount-target"
  description = "Security group for ${local.full_name} S3 Files mount targets"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.full_name}-mount-target"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nfs_from_allowed_sgs" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.mount_targets.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "Allow NFS ingress from client security group"
}
