output "name" {
  description = "Name for the ecs cluster"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "cluster_id" {
  description = "ID for the ecs cluster"
  value       = aws_ecs_cluster.ecs_cluster.id
}
