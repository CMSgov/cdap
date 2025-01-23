locals {
  secret_date = "2020-01-02-09-15-01"
}

data "aws_default_tags" "data_tags" {}

data "aws_secretsmanager_secret" "secret_database_password" {
  count = var.app == "ab2d" ? 1 : 0  # Only for "ab2d"
  
  name = "ab2d/${local.db_name}/module/db/database_password/${local.secret_date}"
}

data "aws_secretsmanager_secret_version" "database_password" {
  count = var.app == "ab2d" ? 1 : 0  # Only for "ab2d"
  
  secret_id = length(data.aws_secretsmanager_secret.secret_database_password) > 0 ? data.aws_secretsmanager_secret.secret_database_password[0].id : null
}

data "aws_secretsmanager_secret" "secret_database_user" {
  name = var.app == "ab2d" ? "ab2d/${local.db_name}/module/db/database_user/${local.secret_date}" : "${var.app}/${var.env}/rds-main-credentials"
}

data "aws_secretsmanager_secret_version" "database_user" {
  secret_id = data.aws_secretsmanager_secret.secret_database_user.id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "target_vpc" {
  filter {
    name = "tag:Name"
    values = [
      var.app == "ab2d" ? local.db_name : "${var.app}-${var.env}-vpc"
    ]
  }
}

data "aws_subnets" "private_subnet_a" {
  filter {
    name   = "tag:Name"
    values = flatten([
      var.app == "ab2d" ? ["${local.db_name}-private-a"] : [],
      var.app == "bcda" && var.env == "opensbx" ? ["${var.app}-${var.env}-az1-data", "${var.app}-${var.env}-az2-data"] : [],
      var.app == "bcda" && var.env != "opensbx" ? ["${var.app}-${var.env}-az1-data", "${var.app}-${var.env}-az2-data", "${var.app}-${var.env}-az3-data"] : []
    ])
  }
}

data "aws_subnet" "private_subnet_b" {
  count = var.app == "ab2d" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${local.db_name}-private-b"]
  }
}

# Fetch the security group for ab2d
data "aws_security_group" "controller_security_group_id" {
  count = var.app == "ab2d" ? 1 : 0 

  tags = {
    Name = "${local.db_name}-deployment-controller-sg"
  }
}

data "aws_kms_alias" "main_kms" {
  count = var.app == "ab2d" ? 1 : 0  # Only query the KMS alias for ab2d
  name  = "alias/${local.db_name}-main-kms"
}
