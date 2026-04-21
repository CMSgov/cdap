output "cluster_arn" {
  description = "ARN of the test ECS cluster"
  value       = aws_ecs_cluster.test.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
