provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/tfstate"
    }
  }
}
resource "aws_s3_bucket" "backend_bucket" {
  bucket = "${var.app}-${var.env}-tfstate"
}

terraform {
  backend "s3" {
    key    = "tfstate/terraform.tfstate"
    bucket = ""
    dynamodb_table = ""
    encrypt        = true

  }
}
