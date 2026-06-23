locals {
  cdap_env = {
    dev     = "non-prod"
    test    = "non-prod"
    prod    = "prod"
    sandbox = "prod"
  }

  private_location_ssm_path = "/cdap/${local.cdap_env[module.platform.env]}/common/nonsensitive/datadog/synthetics-location-id"
}

data "aws_ssm_parameter" "private_location_id" {
  name = local.private_location_ssm_path
}

resource "datadog_synthetics_test" "private_location_connectivity" {
  name    = "cdap-test-private-location-connectivity"
  type    = "api"
  subtype = "tcp"
  status  = "live"

  request_definition {
    host = "api.ddog-gov.com" # arbitrary selection that validates connectivity to Datadog simultaneously
    port = 443
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "2000"
  }

  locations = [data.aws_ssm_parameter.private_location_id.value]

  options_list {
    tick_every = 60
  }

  tags = ["environment:test", "app:cdap", "managed-by:tofu"]
}
