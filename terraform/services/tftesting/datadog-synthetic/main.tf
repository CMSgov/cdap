locals {
  cdap_env = {
    dev     = "non-prod"
    test    = "non-prod"
    prod    = "prod"
    sandbox = "prod"
  }

  private_location_ssm_path = "/cdap/${local.cdap_env[module.platform.env]}/common/nonsensitive/datadog/synthetics_location_id"
}

data "aws_ssm_parameter" "private_location_id" {
  name = local.private_location_ssm_path
}

data "datadog_synthetics_private_location" "cdap" {
  id = data.aws_ssm_parameter.private_location_id.value
}

resource "datadog_synthetics_test" "private_location_connectivity" {
  name    = "cdap-test-private-location-connectivity"
  type    = "api"
  subtype = "tcp"
  status  = "live"

  request_definition {
    host = "api.ddog-gov.com" # arbitrary selection that validates connectivity to Datadog simultaneously
    port = "443"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "2000"
  }

  locations = [data.datadog_synthetics_private_location.cdap.id]

  options_list {
    tick_every = 60
  }

  tags = ["environment:${var.env}", "app:cdap", "managed-by:tofu"]
}
