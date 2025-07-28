locals {
  stdenv = (
    var.app == "bcda" ? (var.env == "sbx" ? "opensbx" : var.env) :
    var.app == "dpc" ? (var.env == "sbx" ? "prod-sbx" : var.env) :
    var.env
  )
  secret_date = "2020-01-02-09-15-01"
  gdit_security_group_names = var.app == "bcda" ? [
    "${var.app}-${local.stdenv}-vpn-private",
    "${var.app}-${local.stdenv}-vpn-public",
    "${var.app}-${local.stdenv}-remote-management",
    "${var.app}-${local.stdenv}-enterprise-tools",
    "${var.app}-${var.env}-allow-zscaler-private"
    ] : var.app == "dpc" ? [
    "${var.app}-${local.stdenv}-remote-management",
    "${var.app}-${local.stdenv}-enterprise-tools",
    "${var.app}-${var.env}-allow-zscaler-private"
  ] : []
  #NOTE: `db_username` and `db_password` are path/names to secrets for secrets manager datasource
  db_username = {
    ab2d = "${var.app}/${local.db_name}/module/db/database_user/${local.secret_date}"
    bcda = "${var.app}/${local.stdenv}/db/username"
    dpc  = "${var.app}/${local.stdenv}/db/username"
  }[var.app]

  db_password = {
    ab2d = "${var.app}/${local.db_name}/module/db/database_password/${local.secret_date}"
    bcda = "${var.app}/${local.stdenv}/db/password"
    dpc  = "${var.app}/${local.stdenv}/db/password"
  }[var.app]
}

# Fetching the secret for database username
data "aws_secretsmanager_secret" "database_user" {
  name = var.legacy ? local.db_username : "${var.app}/${var.env}/db/username"
}

data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.database_user.id
}

# Fetching the secret for database password
data "aws_secretsmanager_secret" "database_password" {
  name = var.legacy ? local.db_password : "${var.app}/${var.env}/db/password"
}

data "aws_secretsmanager_secret_version" "database_password" {
  secret_id = data.aws_secretsmanager_secret.database_password.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "vpc" {
  count = var.legacy ? 1 : 0

  source = "../../modules/vpc"

  app    = var.app
  env    = var.env
  legacy = var.legacy
}

data "aws_subnets" "db" {
  filter {
    name = "tag:Name"
    values = var.legacy ? var.app == "ab2d" ? [
      "${local.db_name}-private-a",
      "${local.db_name}-private-b"
      ] : [
      "${var.app}-${local.stdenv}-az1-data",
      "${var.app}-${local.stdenv}-az2-data",
      "${var.app}-${local.stdenv}-az3-data"
      ] : [
      "${var.app}-east-${local.stdenv}-private-a",
      "${var.app}-east-${local.stdenv}-private-b",
      "${var.app}-east-${local.stdenv}-private-c"
    ]
  }
}

# Fetch the security group for ab2d
data "aws_security_group" "controller_security_group_id" {
  #FIXME: Temporarily disabled in greenfield
  count = var.legacy && var.app == "ab2d" ? 1 : 0

  tags = {
    Name = "${local.db_name}-deployment-controller-sg"
  }
}

data "aws_kms_alias" "main_kms" {
  #FIXME: Temporarily disabled in greenfield
  count = var.legacy && (var.app == "ab2d" || var.app == "dpc") ? 1 : 0 # Only query the KMS alias for ab2d or dpc
  name  = var.app == "ab2d" ? "alias/${local.db_name}-main-kms" : "alias/dpc-${local.stdenv}-master-key"
}

data "aws_kms_alias" "default_rds" {
  name = "alias/aws/rds"
}


data "aws_security_group" "app_sg" {
  #FIXME: Temporarily disabled in greenfield
  count = var.legacy && var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.app}-api-${local.stdenv}"] # This will look for the bcda api app security group named based on the environment
  }
}

data "aws_security_group" "worker_sg" {
  #FIXME: Temporarily disabled in greenfield
  count = var.legacy && var.app == "bcda" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.app}-worker-${local.stdenv}"] #This looks for the bcda worker security group named based on the environment
  }
}

data "aws_security_group" "gdit" {
  for_each = var.legacy ? toset([for name in local.gdit_security_group_names : name if name != null]) : toset([])

  filter {
    name   = "tag:Name" # Filter by 'Name' tag
    values = [each.value]
  }
}

data "aws_security_group" "github_runner" {
  #FIXME: Temporarily disabled in greenfield
  count = var.legacy && var.app == "bcda" ? 1 : 0

  filter {
    name   = "tag:Name"
    values = ["github-actions-action-runner"]
  }
}

data "aws_ssm_parameter" "cdap_mgmt_vpc_cidr" {
  count = var.legacy ? 0 : 1

  name = "/cdap/mgmt-vpc/cidr"
}

data "aws_ssm_parameter" "quicksight_cidr_blocks" {
  count = var.app != "ab2d" ? 1 : 0
  name  = "/${var.app}/${local.stdenv}/quicksight-rds/cidr-blocks"
}

data "aws_security_groups" "dpc_additional_sg" {
  count = var.legacy && var.app == "dpc" ? 1 : 0
  filter {
    name = "description"
    values = [
      "Service traffic from within the VPC"
    ]
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc[0].id]
  }
}

data "aws_iam_role" "rds_monitoring" {
  count = var.legacy && var.app == "dpc" ? 1 : 0
  name  = "rds-monitoring-role"
}
