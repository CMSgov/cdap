locals {
  full_name = "${var.app}-${var.env}-opt-out-export"
  bfd_env   = var.env == "prod" ? "prod" : "test"
  bfd_bucket_access_role = "arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/delegatedadmin/developer/bfd-${local.bfd_env}-eft-${var.app}-ct-bucket-role"
  cron = {
    bcda = {
      prod = "cron(0 1 ? * * *)"
      test = "cron(0 13 ? * * *)"
      dev  = "cron(0 15 ? * * *)"
    }
    dpc = {
      prod = "cron(0 1 ? * * *)"
      test = "cron(0 13 ? * * *)"
      dev  = "cron(0 15 ? * * *)"
    }
  }
  db_sg_name = "${var.app}-${var.env}-db"
  memory_size = {
    bcda = null
    dpc  = 2048
  }
  policies = {
    bcda = data.aws_iam_policy_document.bcda_policies.json
    dpc  = data.aws_iam_policy_document.dpc_policies.json
  }
}

data "aws_ssm_parameter" "bfd_account" {
  name = "/bfd/account-id"
}

data "aws_iam_policy_document" "bcda_policies" {
  statement {
    actions = ["sts:AssumeRole"]
    resources = [
     local.bfd_bucket_access_role
    ]
  }
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "dpc_policies" {
  statement {
    actions = ["sts:AssumeRole"]
    resources = [
     local.bfd_bucket_access_role
    ]
  }

  statement {
    actions = [
      "rds-db:connect"
    ]
    resources = [
      "arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_rds_cluster.this.cluster_resource_id}/${var.env}-dpc_attribution-role",
      "arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_rds_cluster.this.cluster_resource_id}/${var.env}-dpc_consent-role"
    ]
  }
}

data "aws_rds_cluster" "this" {
  cluster_identifier = "${var.app}-${var.env}-aurora"
}

locals {
  #FIXME: database host parameters should be standardized
  db_hosts = sensitive({
    bcda = "postgres://${data.aws_rds_cluster.this.endpoint}:5432/bcda"
    dpc  = data.aws_rds_cluster.this.endpoint
  })
  opt_out_db_host = local.db_hosts[var.app]
}

module "opt_out_export_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Exports data files to a BFD bucket for opt-out"

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = local.policies[var.app]
  }

  schedule_expression = local.cron[var.app][var.env]

  environment_variables = {
    ENV              = var.env
    APP_NAME         = "${var.app}-${var.env}-opt-out-export"
    S3_UPLOAD_BUCKET = "bfd-${var.env == "prod" ? "prod" : "test"}-eft"
    S3_UPLOAD_PATH   = "bfdeft01/${var.app}/out"
    DB_HOST          = local.opt_out_db_host
  }
}

# Add a rule to the database security group to allow access from the function

data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_vpc_security_group_ingress_rule" "function_access" {
  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
  description = "opt-out-export function access"

  security_group_id            = data.aws_security_group.db.id
  referenced_security_group_id = module.opt_out_export_function.security_group_id
}
