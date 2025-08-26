module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=0bd3eeae6b03cc8883b7dbdee5f04deb33468260"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/backup-plan"
  service     = "backup-plan"
  app         = "cdap"
}

locals {
  apps = ["AB2D", "BCDA", "DPC"]
}
