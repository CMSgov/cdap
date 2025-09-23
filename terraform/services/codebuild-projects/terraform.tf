provider "aws" {
  default_tags {
    tags = {
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/codebuild-projects"
      component = "codebuild-projects"
      terraform = true
    }
  }
}

terraform {
  backend "s3" {
    key = "codebuild-projects/terraform.tfstate"
  }
}
