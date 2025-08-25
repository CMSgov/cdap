terraform {
  backend "s3" {
    key = "backup-plan/terraform.tfstate"
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
  default_tags = module.standards.default_tags
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}
