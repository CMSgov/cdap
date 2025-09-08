output "name" {
  description = "Name for the ecs cluster"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "id" {
  description = "ID for the ecs cluster"
  value       = aws_ecs_cluster.ecs_cluster.id
}
