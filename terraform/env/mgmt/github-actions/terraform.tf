provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
      component = "github-actions"
      Terraform = true
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "bcda-terraform-state"
    key            = "github-runners/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bcda-terraform-table"
    encrypt        = "1"
    kms_key_id     = "alias/bcda-terraform-state"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
  required_version = "~> 1.5.3"
}
