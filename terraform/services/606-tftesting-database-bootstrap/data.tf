locals {
  aurora_app_name = "cdap"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "cluster_resource_id" {
  name = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/db-cluster-resource-id"
}

data "aws_ssm_parameter" "db_security_group_id" {
  name = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/db-security-group-id"
}

# Firm convention: ${repo_name}-${env}-github-actions
data "aws_iam_role" "ci" {
  name = "${var.repo_name}-${module.platform.env}-github-actions"
}

data "aws_iam_role" "human_access_admins" {
  for_each = var.enable_human_database_access ? toset(var.human_access_admin_role_names) : toset([])
  name     = each.value
}

data "aws_ssm_parameter" "codebuild_security_group_id" {
  name = "/cdap/${module.platform.account_env_suffix}/codebuild/nonsensitive/security-group-id"
}
