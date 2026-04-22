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
}
