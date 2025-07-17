terraform {
  backend "s3" {
    key = "kms-keys/terraform.tfstate"
  }
}

provider "aws" {
  default_tags {
    tags = module.standards.default_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = module.standards.default_tags
  }
}
