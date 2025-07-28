terraform {
  backend "s3" {
    key = "platform/terraform.tfstate"
  }
}

provider "aws" {
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

