provider "aws" {
  default_tags {
    tags = {
      application = var.app
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/ecr-cleanup"
      component   = "ecr-cleanup"
      environment = var.env
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "ecr-cleanup/terraform.tfstate"
  }
}
