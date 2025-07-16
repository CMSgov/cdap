terraform {
  backend "s3" {
    key = "kms-keys/terraform.tfstate"
  }

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.secondary]
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/kms-keys"
    }
  }
}

provider "aws" {
  alias = "secondary"
}
