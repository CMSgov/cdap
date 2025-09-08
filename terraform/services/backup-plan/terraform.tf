terraform {
  backend "s3" {
    key = "backup-plan/terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}
