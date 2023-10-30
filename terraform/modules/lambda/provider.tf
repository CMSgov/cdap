provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "opt-out-inbound"
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
  required_version = "= 1.5.5"
}
