locals {
  private_location_ssm_path = "/cdap/${module.platform.env}/datadog/nonsensitive/private_location_config_id"
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
