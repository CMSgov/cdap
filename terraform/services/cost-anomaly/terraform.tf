terraform {
  backend "s3" {
    key = "cost-anomaly/terraform.tfstate"
  }
}

provider "aws" {
  default_tags {
    tags = {
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/cost-anomaly"
      component   = "cost-anomaly"
      environment = var.env
      terraform   = true
    }
  }
}
