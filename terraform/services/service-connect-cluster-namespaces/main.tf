terraform {
  required_version = "~> 1.10.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source to fetch all ECS cluster ARNs
data "aws_ecs_clusters" "all" {}

# Data source to fetch details for each cluster
data "aws_ecs_cluster" "clusters" {
  for_each = toset([
    for arn in data.aws_ecs_clusters.all.cluster_arns :
    element(split("/", arn), 1)
  ])

  cluster_name = each.key
}

# Create Service Discovery HTTP Namespace for each ECS Cluster
resource "aws_service_discovery_http_namespace" "ecs_namespaces" {
  for_each = data.aws_ecs_cluster.clusters

  name        = each.value.cluster_name
  description = "Service Connect namespace for ${each.value.cluster_name}"

  tags = {
    Name        = "Service Connect - ${each.value.cluster_name}"
    Cluster     = each.value.cluster_name
    Environment = try(each.value.tags["Environment"], "unknown")
    ManagedBy   = "Terraform"
  }
}
