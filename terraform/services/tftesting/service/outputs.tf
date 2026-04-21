output "cluster_arn" {
  description = "ARN of the test ECS cluster"
  value       = aws_ecs_cluster.test.arn
}

output "service_name" {
  description = "Name of the ECS service created by the module"
  value       = module.ecs_service.service_name # adjust to your module's output name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "execution_role_arn" {
  value = aws_iam_role.execution.arn
}
