provider "aws" {
  default_tags {
    tags = {
      application = "dpc"
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/api-waf-sync"
      component   = "api-waf-sync"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "api-waf-sync/terraform.tfstate"
  }
}
