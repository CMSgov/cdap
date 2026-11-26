output "function_name" {
  description = "Name of the log group audit Lambda function"
  value       = module.log_group_audit_function.name
}

output "results_bucket" {
  description = "Bucket holding audit results, partitioned by app and env"
  value       = module.results_bucket.id
}
