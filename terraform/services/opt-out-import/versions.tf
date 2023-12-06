provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "opt-out-import"
      Terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "opt-out-import/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
  required_version = "~> 1.5.5"
}
