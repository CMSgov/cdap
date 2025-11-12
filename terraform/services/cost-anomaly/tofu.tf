terraform {
  backend "s3" {
    key = "cost-anomaly/terraform.tfstate"
  }
}

variable "region" {
  default  = "us-east-1"
  nullable = false
  type     = string
}

variable "secondary_region" {
  default  = "us-west-2"
  nullable = false
  type     = string
}

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
