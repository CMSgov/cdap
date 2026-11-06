provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tfstate"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tfstate"
    }
  }
}

module "platform" {
  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tfstate/"
  service     = "tfstate"
}

terraform {
  # Comment out backend block and init without -backend-config for initial creation of resources
  backend "s3" {
    key = "tfstate/terraform.tfstate"
  }
}
