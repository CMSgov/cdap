resource "aws_db_instance" "api" {
  identifier            = "${var.env}-${var.app}"
  allocated_storage     = 10
  max_allocated_storage = 100
  storage_type          = "gp2"
  engine                = "postgres"
  engine_version        = "11"
  instance_class        = "db.m6i.large"
  skip_final_snapshot   = false
}
