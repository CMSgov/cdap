terraform {
  backend "s3" {
    key = "backup-plan/terraform.tfstate"
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
  default_tags {
    tags = {
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/backup-plan"
      component   = "backup-plan"
      environment = var.env
      terraform   = true
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = {
      business    = "oeda"
      code        = "https://github.com/CMSgov/cdap/tree/main/terraform/services/backup-plan"
      component   = "backup-plan"
      environment = var.env
      terraform   = true
    }
  }
}
