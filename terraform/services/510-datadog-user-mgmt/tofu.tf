terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
  }

  backend "s3" {
    key = "510-datadog-agents-api-keys/terraform.tfstate"
  }
}

provider "datadog" {
  api_key = sensitive(module.standards.ssm.datadog.api_key.value)
  app_key = sensitive(module.standards.ssm.datadog.application_key.value)
  api_url = "https://api.ddog-gov.com"
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = module.standards.default_tags
  }
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
  default_tags {
    tags = module.standards.default_tags
  }
}

module "standards" {
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = "prod"
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${path.module}/"
  service      = replace(path.module, "/[0-9]/", "")
  ssm_root_map = { datadog = "/cdap/prod/datadog/cicd" }
}
