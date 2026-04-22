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
    key = "503-datadog-agents-api-keys/terraform.tfstate"
  }
}

provider "datadog" {
  api_key = sensitive(data.aws_ssm_parameter.cdap_datadog_api_key.value)
  app_key = sensitive(data.aws_ssm_parameter.cdap_datadog_application_key.value)
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