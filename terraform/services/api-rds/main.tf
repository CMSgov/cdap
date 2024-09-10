resource "aws_db_instance" "api" {
  identifier            = "${var.app}-${var.env}"
  allocated_storage     = 500
  max_allocated_storage = 0
  storage_encrypted     = true
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade",
  ]
  deletion_protection                 = true
  storage_type                        = "io1"
  skip_final_snapshot                 = true
  engine                              = "postgres"
  iam_database_authentication_enabled = false
  engine_version                      = "15.5"
  instance_class                      = "db.m6i.2xlarge"
  tags = {
    Name             = "${var.app}-${var.env}-rds"
    "cpm backup"     = "Monthly"
    contact          = "ab2d-ops@semanticbits.com"
    environment      = "${var.app}-${var.env}"
    role             = "db"
    terraform_module = "data"
  }
}
