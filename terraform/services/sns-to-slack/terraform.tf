provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/sns-to-slack"
      component   = "sns-to-slack"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "sns-to-slack/terraform.tfstate"
  }
}
