terraform {
  backend "s3" {
    key = "cost-anomaly/terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
  }
}
