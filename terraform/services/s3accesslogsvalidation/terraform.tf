provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      application = "cdap"
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/s3accesslogsvalidation"
      component   = "s3accesslogsvalidation"
      environment = "test"
      terraform   = true
    }
  }
}

terraform {
  backend "s3" {
    key = "s3accesslogsvalidation/terraform.tfstate"
  region = "us-east-1"
  }
}
