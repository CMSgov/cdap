data "aws_vpc" "this" {
  filter {
    name   = "tag:stack"
    values = [var.env]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.app}-east-${var.env}"]
  }
}
