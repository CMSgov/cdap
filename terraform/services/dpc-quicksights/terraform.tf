provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/dpc-quicksights"
      component   = "dpc-quicksights"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "dpc-quicksights/terraform.tfstate"
  }
}
