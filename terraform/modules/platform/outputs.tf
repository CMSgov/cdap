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

output "sdlc_env" {
  description = "The SDLC (production vs non-production) environment."
  sensitive   = false
  value       = local.sdlc_env
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

output "default_tags" {
  description = "Tags for use in AWS provider block `default_tags`. Merges collection of standard tags with optional, user-specificed `additional_tags`"
  value       = merge(var.additional_tags, local.static_tags)
  sensitive   = false
}

output "vpc_id" {
  description = "The current environment's VPC (data.aws_vpc) ID value."
  sensitive   = true
  value       = data.aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "The current environment and VPC's private subnet ids"
  sensitive   = true
  value       = data.aws_subnet.private
}

output "public_subnet_ids" {
  description = "The current environment and VPC's public subnet ids"
  sensitive   = true
  value       = data.aws_subnet.public
}

output "logging_bucket" {
  description = "The designated access log bucket for this current environment"
  value       = data.aws_s3_bucket.access_logs
}

output "security_groups" {
  description = "Common security groups relevant to the current environment."
  sensitive   = false
  value       = data.aws_security_group.this
}

output "platform_cidr" {
  value       = data.aws_ssm_parameter.platform_cidr.value
  description = "The CIDR-range for the CDAP-managed VPC for CI and other administrative functions."
  sensitive   = true
}

output "kion_roles" {
  value = data.aws_iam_role.this
  sensitive = false
}
