data "aws_ecs_cluster" "cluster_test" {
  cluster_name = local.cluster_name
}

data "aws_service_discovery_http_namespace" "tftesting" {
    name        = "${local.cluster_name}.sc.internal.cms.gov"
}
