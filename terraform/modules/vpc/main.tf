data "aws_vpc" "this" {
  filter {
    name   = "tag:stack"
    values = [
      var.app == "ab2d" && var.env == "mgmt" ? "dev" :
      var.app == "ab2d" && var.env == "sbx" ? "sandbox" :
      var.app == "ab2d" && var.env == "test" ? "impl" :
      var.app == "bcda" && var.env == "mgmt" ? "managed" :
      var.app == "bcda" && var.env == "sbx" ? "opensbx" :
      var.app == "dpc" && var.env == "mgmt" ? "management" :
      var.app == "dpc" && var.env == "sbx" ? "prod-sbx" :
      var.env
    ]
  }

  dynamic "filter" {
    for_each = var.app == "bcda" || var.app == "dpc" || var.legacy == true ? [1] : []
    content {
      # Use tag:Name when legacy is true, otherwise fallback to tag:application
      name = var.legacy == true ? "tag:Name" : "tag:application"
      
      values = var.legacy == true ? [
        "${var.app}-east-${var.env}"  # Greenfield account name format (e.g., dpc-east-test)
      ] : [
        var.app  # Non-Greenfield account uses the tag:application value (e.g., dpc)
      ]
    }
  }
}
