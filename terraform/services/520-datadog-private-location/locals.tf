locals {
  vpc_names = yamldecode(file("${path.module}/config/${var.env}.yml")).vpcs
}
