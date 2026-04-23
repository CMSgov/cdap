terraform {
  required_version = ">= 1.6.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }

}

provider "datadog" {
  api_url = "https://app.ddog-gov.com"
}
