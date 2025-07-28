locals {
  full_name   = "${var.app}-${var.env}-admin-create-group"
  db_sg_name  = var.legacy ? "bcda-${var.env == "sbx" ? "opensbx" : var.env}-rds" : "bcda-${var.env}-db"
  memory_size = 2048
}

module "admin_create_group_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Creates a group for the supplied CMS ID."

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-admin-create-group"
  }

  legacy = var.legacy
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
  description = "admin-create-group function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.admin_create_group_function.security_group_id
}
