module "vpc" {
  source = "../../modules/vpc"
  app    = var.app
  env    = var.env
}

resource "aws_security_group" "zscaler_public" {
  name        = "${var.app}-${var.env}-allow-zscaler-public"
  description = "Allow public zscaler traffic"
  vpc_id      = module.vpc.id
}

resource "aws_security_group" "zscaler_private" {
  name        = "${var.app}-${var.env}-allow-zscaler-private"
  description = "Allow internet zscaler traffic private"
  vpc_id      = module.vpc.id
}

resource "aws_security_group" "packer" {
  name        = "${var.app}-${var.env}-packer"
  description = "Access for packer instances"
  vpc_id      = module.vpc.id
}
