provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/zscaler-security-groups"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "zscaler-security-groups/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
  required_version = "~> 1.5.5"
}
