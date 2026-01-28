provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

terraform {
  backend "s3" {
    key = "service-connect-cluster-namespaces/terraform.tfstate"
  }
}
