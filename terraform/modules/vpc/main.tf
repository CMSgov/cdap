data "aws_vpc" "this" {
  dynamic "filter" {
    for_each = contains(["ab2d", "bcda", "dpc", "cdap"], var.app) ? [1] : []
    content {
      name   = "tag:Name"
      values = ["${var.app}-east-${var.env}"]
    }
  }
}
