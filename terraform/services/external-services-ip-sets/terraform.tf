provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/external-services-ip-sets"
      component = "external-services-ip-sets"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "external-services-ip-sets/terraform.tfstate"
  }
}
