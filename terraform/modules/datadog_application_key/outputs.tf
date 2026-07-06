output "ssm_parameter" {
  description = "Application key for CICD use"
  value       = aws_ssm_parameter.datadog_application_key
  sensitive   = true
}

output "permissions" {
  description = "List of application key scopes that allow Tofu management of resources."
  value       = local.application_key_permissions
}
