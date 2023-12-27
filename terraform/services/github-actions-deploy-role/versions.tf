provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/github-actions-deploy-role"
      component = "github-actions"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "github-actions-deploy-role/terraform.tfstate"
  }
}
