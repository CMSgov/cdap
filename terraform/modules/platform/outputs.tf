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
  description = "Map of tags for use in AWS provider block `default_tags`. Merges collection of standard tags with optional, user-specificed `additional_tags`"
  value       = merge(var.additional_tags, local.static_tags)
  sensitive   = false
}

output "vpc_id" {
  description = "The current environment's VPC ID value"
  sensitive   = false
  value       = data.aws_vpc.this.id
}

output "private_subnets" {
  description = "Map of current VPCs **private** [aws_subnet data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet), keyed by `subnet_id`"
  sensitive   = true
  value       = data.aws_subnet.private
}

output "public_subnets" {
  description = "Map of current VPCs **public** [aws_subnet data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet), keyed by `id`"
  sensitive   = true
  value       = data.aws_subnet.public
}

output "logging_bucket" {
  description = "The designated access log bucket [aws_s3_bucket data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket#attribute-reference) for the current environment"
  value       = data.aws_s3_bucket.access_logs
  sensitive   = false
}

output "security_groups" {
  description = "Map of current VPC's common [aws_security_group data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group#attribute-reference), keyed by `name`"
  sensitive   = true
  value       = data.aws_security_group.this
}

output "platform_cidr" {
  description = "The CIDR-range for the CDAP-managed VPC for CI and other administrative functions."
  sensitive   = true
  value       = data.aws_ssm_parameter.platform_cidr.value
}

output "kion_roles" {
  description = "Map of common kion/cloudtamer [aws_iam_role data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role#attributes-reference), keyed by `name`."
  sensitive   = false
  value       = data.aws_iam_role.this
}

output "nat_gateways" {
  description = "Map of current VPC's **available** [aws_nat_gateway data sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role#attributes-reference), keyed by `id`."
  sensitive   = true
  value       = data.aws_nat_gateway.this
}
