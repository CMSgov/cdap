### Get vpc reference
module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
}

### public
resource "aws_security_group" "zscaler_public" {
  name        = "${var.app}-${var.env}-allow-zscaler-public"
  description = "Allow public zscaler traffic"
  vpc_id      = module.vpc.id
}

#resource "aws_vpc_security_group_ingress_rule" "zscaler_allow_public" {
#  for_each          = toset(var.public_cidrs)
#  security_group_id = aws_security_group.zscaler_public.id
#  cidr_ipv4         = each.key
#  ip_protocol       = -1
#}
### private
resource "aws_security_group" "zscaler_private" {
  name        = "${var.app}-${var.env}-allow-zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
}

#resource "aws_vpc_security_group_ingress_rule" "zscaler_allow_private" {
#  for_each          = toset(var.private_cidrs)
#  ip_protocol       = -1
#  cidr_ipv4         = each.key
#  security_group_id = aws_security_group.zscaler_private.id
#}
