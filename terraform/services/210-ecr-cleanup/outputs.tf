output "function_name" {
  description = "Name of the ECR cleanup Lambda function"
  value       = module.ecr_cleanup_function.name
}
