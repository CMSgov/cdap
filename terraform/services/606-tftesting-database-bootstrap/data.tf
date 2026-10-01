locals {
  aurora_app_name = "cdap"
}

data "aws_ssm_parameter" "cluster_resource_id" {
  count = local.tftesting_cluster_exists ? 1 : 0
  name  = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/db-cluster-resource-id"
}

data "aws_ssm_parameter" "db_security_group_id" {
  count = local.tftesting_cluster_exists ? 1 : 0

  name = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/db-security-group-id"
}

# Firm convention: ${repo_name}-${env}-github-actions
data "aws_iam_role" "ci" {
  name = "${var.repo_name}-${module.platform.env}-github-actions"
}


data "aws_ssm_parameter" "codebuild_security_group_id" {
  name = "/cdap/${module.platform.account_env_suffix}/codebuild/nonsensitive/security-group-id"
}
