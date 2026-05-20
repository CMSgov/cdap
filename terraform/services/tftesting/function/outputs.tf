output "function_name" {
  description = "Name of the test Lambda function"
  value       = module.tftesting_function.name
}

output "function_arn" {
  description = "ARN of the test Lambda function"
  value       = module.tftesting_function.arn
}

output "function_version" {
  description = "Published version of the test Lambda"
  value       = module.tftesting_function.function_version
}
