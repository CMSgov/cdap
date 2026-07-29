data "aws_ecs_cluster" "cluster_test" {
  cluster_name = local.cluster_name
}