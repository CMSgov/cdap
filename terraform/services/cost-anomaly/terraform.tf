terraform {
  backend "s3" {
    key = "cost-anomaly/terraform.tfstate"
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
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
