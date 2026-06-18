output "ssm_parameter" {
  description = "Application key for CICD use"
  value       = aws_ssm_parameter.datadog_application_key
  sensitive   = true
}
