output "ssm_parameter_name" {
  description = "The SSM path storing the generated API key."
  sensitive   = true
  value       = aws_ssm_parameter.datadog_api_key.name
}

output "api_key_id" {
  value = datadog_api_key.this
}
