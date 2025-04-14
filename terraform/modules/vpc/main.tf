data "aws_vpc" "this" {
  filter {
    name = "tag:stack"
    values = [
      var.app == "ab2d" && var.env == "mgmt" ? "dev" : # Yes, dev is the stack name for the ab2d mgmt vpc
      var.app == "ab2d" && var.env == "sandbox" ? "sandbox" :
      var.app == "ab2d" && var.env == "test" ? "impl" :
      var.app == "bcda" && var.env == "mgmt" ? "managed" :
      var.app == "bcda" && var.env == "sandbox" ? "sandbox" :
      var.app == "dpc" && var.env == "mgmt" ? "management" :
      var.app == "dpc" && var.env == "sandbox" ? "prod-sandbox" :
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
