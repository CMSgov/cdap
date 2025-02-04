locals {
  full_name   = "${var.app}-${var.env}-admin-create-aco-creds"
  db_sg_name  = "bcda-${var.env}-rds"
  memory_size = 256
}

data "aws_ssm_parameter" "aco_creds_bucket_role_arn" {
  name = "arn:aws:s3:::bcda-aco-credentials/${var.env}"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["s3:PutObject"]
    resources = [data.aws_ssm_parameter.aco_creds_bucket_role_arn.value]
  }
}

module "admin_create_aco_creds_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Finds and Creates ACO Credentials for passed in ACO ID and IP addresses"

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-admin-create-aco-creds"
  }
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
  description = "admin-create-aco-creds function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.admin_create_aco_creds_function.security_group_id
}
