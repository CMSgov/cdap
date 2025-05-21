output "app" {
  description = "The short name for the delivery team or ADO."
  sensitive   = false
  value       = local.app
}

output "service" {
  description = "The name of the current service or terraservice."
  sensitive   = false
  value       = local.service
}

output "region_name" {
  description = "The region name associated with the current caller identity"
  sensitive   = false
  value       = data.aws_region.this.name
}

output "account_id" {
  description = "The AWS account ID associated with the current caller identity"
  sensitive   = true
  value       = data.aws_caller_identity.this.account_id
}

output "env" {
  description = "The solution's application environment name."
  sensitive   = false
  value       = local.env
}

output "default_tags" {
  description = "Map of tags for use in AWS provider block `default_tags`. Merges collection of standard tags with optional, user-specificed `additional_tags`"
  sensitive   = false
  value       = merge(var.additional_tags, local.static_tags)
}

output "default_permissions_boundary" {
  description = "Default permissions boundary [aws_iam_policy data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy#attribute-reference)"
  sensitive   = false
  value       = merge(var.additional_tags, local.static_tags)
}
