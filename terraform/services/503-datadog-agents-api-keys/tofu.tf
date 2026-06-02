terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }

  backend "s3" {
    key = "503-datadog-config/terraform.tfstate"
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

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = merge(
    {
      datadog = "/cdap/${local.cdap_env}/datadog/cicd/"
    },
    local.shares_ssm_roots # adds "external_bb", "external_bfd", etc. dynamically
  )
}
