provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/snyk-integration"
      component = "synk"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "ecr-snyk-integration/terraform.tfstate"
  }
}
