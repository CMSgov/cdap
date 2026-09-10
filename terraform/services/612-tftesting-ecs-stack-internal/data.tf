data "aws_ecs_cluster" "cluster_test" {
  cluster_name = local.cluster_name
}

data "aws_route53_zone" "internal" {
  name         = "${module.platform.env}.${module.platform.app}.internal.cms.gov"
  private_zone = true
}
