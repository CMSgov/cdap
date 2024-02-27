provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/opt-out-test"
      component   = "opt-out-test"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "opt-out-test/terraform.tfstate"
  }
}
