provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/aurora-export"
      component = "aurora-export"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "aurora-export/terraform.tfstate"
  }
}
