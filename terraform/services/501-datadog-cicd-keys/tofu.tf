terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
  }

  backend "s3" {
    key = "501-datadog-cicd-keys/terraform.tfstate"
  }
}

provider "datadog" {
  api_key = sensitive(module.platform.ssm.init_datadog.init_api_key.value)
  app_key = sensitive(module.platform.ssm.init_datadog.init_application_key.value)
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
