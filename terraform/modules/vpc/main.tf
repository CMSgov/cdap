data "aws_vpc" "this" {
  filter {
    name   = "tag:stack"
    values = [var.app_env == "test" && var.app_team == "ab2d" ? "impl" : var.app_env]
  }
  dynamic "filter" {
    for_each = var.app_team == "bcda" || var.app_team == "dpc" ? [1] : []
    content {
      name   = "tag:application"
      values = [var.app_team]
    }
  }
}
