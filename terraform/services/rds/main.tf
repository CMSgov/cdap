provider "aws" {
  region = "us-east-1"
}

resource "aws_db_instance" "rds" {
  identifier           = "${var.env}-${var.name}"
  allocated_storage    = 10
  max_allocated_storage = 100
  storage_ty[e         = "gp2"
  engine               = "postgres"
  engine_version       = "11"
  instance_class       = "db.m6i.large"
  skip_final_snapshot  = true
}
