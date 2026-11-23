provider "aws" {
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}"
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = {
      Terraform = true
      business  = "oeda"
      code      = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}"
    }
  }
}

module "platform" {
  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}

terraform {
  # Comment out backend block and init without -backend-config for initial creation of resources
  # The key intentionally stays "tfstate/" (no number prefix) so existing state is unaffected
  backend "s3" {
    key = "tfstate/terraform.tfstate"
  }
}
