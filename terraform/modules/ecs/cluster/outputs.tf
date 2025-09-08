output "cluster" {
  description = "The ecs cluster for the given inputs."
  value       = aws_ecs_cluster.this
}
