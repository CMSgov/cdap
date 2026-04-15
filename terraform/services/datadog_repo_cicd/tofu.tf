provider "datadog" {
  api_key = module.
  app_key = var.datadog_init_application_key
  api_url = "https://api.ddog-gov.com"
}

terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~>4.4"
    }
  }
}
