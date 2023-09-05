provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "ab2d-bcda-dpc-platform"
      Terraform = true
    }
  }
}
terraform {
  required_providers {
    archive = {
      source = "hashicorp/archive"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
  required_version = "= 1.0.0"
}
