# This root tofu.tf is symlink'd to by all per-env Terraservices. Changes to this tofu.tf apply to
# _all_ Terraservices, so be careful!

locals {
  app              = "cdap"
  state_bucket = "cdap-mgmt-s3.tfbackend"
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
  region = var.region
  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias = "secondary"

  region = var.secondary_region
  default_tags {
    tags = local.default_tags
  }
}

terraform {
  backend "s3" {
    bucket       = local.state_bucket
    key          = "ops/services/${local.service}/tofu.tfstate"
    region       = var.region
    encrypt      = true
    kms_key_id   = "alias/cdap-mgmt"
    use_lockfile = true
  }
}
