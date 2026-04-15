output "value" {
  description = "The generated API key."
  sensitive   = true
  value       = datadog_api_key.key
}

output "id" {
  value = datadog_api_key.id
}
