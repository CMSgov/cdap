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

output "primary_region" {
  description = "The primary data.aws_region object from the current caller identity"
  sensitive   = false
  value       = data.aws_region.this
}

output "secondary_region" {
  description = "The secondary data.aws_region object associated with the secondary region."
  sensitive   = false
  value       = data.aws_region.secondary
}

output "account_id" {
  description = "Deprecated. Use `aws_caller_identity.account_id`. The AWS account ID associated with the current caller identity"
  sensitive   = true
  value       = data.aws_caller_identity.this.account_id
}

output "aws_caller_identity" {
  description = "The current data.aws_caller_identity object."
  sensitive   = true
  value       = data.aws_caller_identity.this
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
  value       = data.aws_iam_policy.permissions_boundary
}

output "is_ephemeral_env" {
  description = "Returns true when environment is _ephemeral_, false when _established_"
  sensitive   = false
  value       = local.env != local.parent_env
}

output "parent_env" {
  description = "The solution's source environment. For established environments this is equal to the environment's name"
  sensitive   = false
  value       = local.parent_env
}
