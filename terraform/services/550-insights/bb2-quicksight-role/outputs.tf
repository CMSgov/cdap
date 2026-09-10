output "role_arn" {
  description = "Role ARN for the bb2 quicksight role in the dasg insights account"
  value       = aws_iam_role.bb2_quicksight.arn
}
