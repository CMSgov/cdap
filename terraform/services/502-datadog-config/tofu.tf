terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
  }

  backend "s3" {
    key = "502-datadog-config/terraform.tfstate"
  }
}

provider "datadog" {
  api_key = sensitive(data.aws_ssm_parameter.cdap_datadog_api_key.value)
  app_key = sensitive(data.aws_ssm_parameter.cdap_datadog_application_key.value)
  api_url = "https://api.ddog-gov.com"
}
