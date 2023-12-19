provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      business  = "oeda"
    }
  }
}

terraform {
  # Uncomment backend and init with -backend-config to migrate to and manage remote state
  #backend "s3" {
  #  key = "tfstate/terraform.tfstate"
  #}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
  required_version = "~> 1.5.5"
}
