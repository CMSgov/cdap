provider "aws" {
  default_tags {
    tags = var.legacy ? module.standards[0].default_tags : module.platform[0].default_tags
  }
}

terraform {
  backend "s3" {
    key = "api-rds/terraform.tfstate"
  }
}
