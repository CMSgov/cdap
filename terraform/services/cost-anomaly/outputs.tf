output "function_role_arn" {
  value = module.cost_anomaly_function.role_arn
}

output "zip_bucket" {
  value = module.cost_anomaly_function.zip_bucket
}
