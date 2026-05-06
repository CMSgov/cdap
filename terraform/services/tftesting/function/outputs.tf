output "function_name" {
  description = "Name of the test Lambda function"
  value       = module.test_lambda.function_name
}

output "function_arn" {
  description = "ARN of the test Lambda function"
  value       = module.test_lambda.alias_arn
}

output "function_version" {
  description = "Published version of the test Lambda"
  value       = module.test_lambda.function_version
}
