data "aws_vpc" "this" {
  filter {
    name = "tag:stack"
    values = [
      var.app == "ab2d" && var.env == "mgmt" ? "dev" :
      var.app == "ab2d" && var.env == "sbx" ? "sandbox" :
      var.app == "ab2d" && var.env == "test" ? "impl" :
      var.app == "bcda" && var.env == "mgmt" ? "managed" :
      var.app == "bcda" && var.env == "sbx" ? "opensbx" :
      var.app == "dpc" && var.env == "sbx" ? "prod-sbx" :
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
