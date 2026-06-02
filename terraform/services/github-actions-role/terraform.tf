provider "aws" {
  default_tags {
    tags = module.standards.default_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = module.standards.default_tags
  }
}

terraform {
  backend "s3" {
    key = "github-actions-role/terraform.tfstate"
  }
}
module "standards" {
  source      = "github.com/CMSgov/cdap//terraform/modules/standards?ref=0bd3eeae6b03cc8883b7dbdee5f04deb33468260"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/github-actions-role"
  service     = "github-actions-role"
}

