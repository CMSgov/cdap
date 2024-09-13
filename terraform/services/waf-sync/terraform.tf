provider "aws" {
  default_tags {
    tags = {
      application = "dpc"
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/waf-sync"
      component   = "waf-sync"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "waf-sync/terraform.tfstate"
  }
}
