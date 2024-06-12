data "aws_vpc" "this" {
  filter {
    name = "tag:stack"
    values = [
      var.env == "sbx" && var.app == "ab2d" ? "sandbox" :
      var.env == "sbx" && var.app == "bcda" ? "opensbx" :
      var.env == "mgmt" && var.app == "bcda" ? "managed" :
      var.env == "sbx" && var.app == "dpc" ? "prod-sbx" :
      var.env == "test" && var.app == "ab2d" ? "impl" :
      var.env
    ]
  }
  dynamic "filter" {
    for_each = var.app == "bcda" || var.app == "dpc" ? [1] : []
    content {
      name   = "tag:application"
      values = [var.app]
    }
  }
}
