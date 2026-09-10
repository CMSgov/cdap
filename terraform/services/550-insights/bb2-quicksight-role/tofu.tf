
locals {
  static_tags = {
    application    = "cdap"
    business       = "oeda"
    environment    = "prod"
    service        = basename(abspath(path.module))
    terraform      = true
    tf_root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = local.static_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = local.static_tags
  }
}
