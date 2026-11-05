locals {
  config           = yamldecode(file("${path.module}/config/${var.env}.yml"))
  cluster_name     = try(local.config.ecs.cluster, "cdap-${var.env}")
  services_enabled = try(local.config.services_enabled, "false")
}

