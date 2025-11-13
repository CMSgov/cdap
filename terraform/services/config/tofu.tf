provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias = "secondary"
  region = "us-west-2"
  default_tags {
    tags = local.default_tags
  }
}

terraform {
  backend "s3" {
    key = "config/terraform.tfstate"
  }
}
