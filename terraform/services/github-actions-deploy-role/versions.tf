provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "github-actions"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "github-actions-deploy-role/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
  required_version = "~> 1.5.5"
}
