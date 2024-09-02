provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/github-actions-access"
      component = "github-actions"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "github-actions-access/terraform.tfstate"
  }
}
