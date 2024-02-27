output "arn" {
  description = "ARN for the GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}
