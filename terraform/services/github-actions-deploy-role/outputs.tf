output "role_arn" {
  description = "ARN for the GitHub Actions deploy role"
  value       = aws_iam_role.github_actions_deploy.arn
}
