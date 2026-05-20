output "datadog_application_key" {
  description = "Application key for CICD use"
  value       = aws_ssm_parameter.datadog_application_key
  sensitive   = true
}
