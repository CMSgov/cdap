terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
  }

  backend "s3" {
    key = "tftesting/datadog-synthetic/terraform.tfstate"
  }
}

provider "datadog" {
  api_key = sensitive(module.platform.ssm.datadog.api_key.value)
  app_key = sensitive(module.platform.ssm.datadog.application_key.value)
  api_url = "https://api.ddog-gov.com"
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = module.platform.default_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = module.platform.default_tags
  }
}

module "platform" {
  source    = "../../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = "test"
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/tftesting/datadog-synthetic"
  service      = "tftesting"
  ssm_root_map = { datadog = "/cdap/test/datadog/cicd/" }
}
