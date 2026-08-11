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
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = "prod"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${path.module}/"
  service     = replace(path.module, "/[0-9]/", "")
}
