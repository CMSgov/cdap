provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business = "oeda"
      code = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/tfstate"
    }
  }
}

terraform {
  # Uncomment backend and init with -backend-config to migrate to and manage remote state
  #backend "s3" {
  #  key = "tfstate/terraform.tfstate"
  #}
}
