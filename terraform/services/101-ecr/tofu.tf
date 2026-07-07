terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }

  backend "s3" {
    key = "ecr/terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
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

module "platform" {
  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "cdap"
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}
