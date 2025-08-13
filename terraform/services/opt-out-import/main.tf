locals {
  full_name              = "${var.app}-${var.env}-opt-out-import"
  bfd_env                = var.env == "prod" ? "prod" : "test"
  db_sg_name             = "${var.app}-${var.env}-db"
  bfd_bucket_access_role = "arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/delegatedadmin/developer/bfd-${local.bfd_env}-eft-${var.app}-ct-bucket-role"
  policies = {
    bcda = data.aws_iam_policy_document.bcda_policies.json
    dpc  = data.aws_iam_policy_document.dpc_policies.json
  }
  cluster_identifier = var.app == "dpc" ? "dpc-${var.env}" : "${var.app}-${var.env}-aurora"
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
    resources = ["arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_rds_cluster.this.cluster_resource_id}/${var.env}-dpc_consent-role"]
  }

}

data "aws_rds_cluster" "this" {
  cluster_identifier = local.cluster_identifier
}

locals {
  #FIXME: database host parameters should be standardized
  db_hosts = sensitive({
    bcda = "postgres://${data.aws_rds_cluster.this.endpoint}:5432/bcda"
    dpc  = data.aws_rds_cluster.this.endpoint
  })
  opt_out_db_host = local.db_hosts[var.app]
}

module "opt_out_import_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = "bootstrap"
  runtime = "provided.al2"

  function_role_inline_policies = {
    assume-bucket-role = local.policies[var.app]
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-import"
    DB_HOST  = local.opt_out_db_host
  }
}

# Set up queue for receiving messages when a file is added to the bucket

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "opt_out_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.opt_out_import_function.name
  sns_topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
}

# Add a rule to the database security group to allow access from the function

data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_security_group_rule" "function_access" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  description = "opt-out-import function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.opt_out_import_function.security_group_id
}
