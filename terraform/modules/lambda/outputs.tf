output "lambda_role_arn" {
  description = "ARN of the IAM role for the lambda"
  value       = aws_iam_role.lambda.arn
}
