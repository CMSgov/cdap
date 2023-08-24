output "webhook_endpoint" {
  value       = module.github-actions.webhook.endpoint
  description = "API Gateway endpoint required by the GitHub App"
}
