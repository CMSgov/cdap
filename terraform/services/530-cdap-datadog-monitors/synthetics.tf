data "datadog_synthetics_locations" "all" {}

locals {
  # Select the private location matching this environment.
  # Non-prod environments use the "cdap-non-prod" private location;
  # prod uses "cdap-prod".
  synthetics_location_prefix = var.env == "prod" ? "cdap-prod" : "cdap-non-prod"

  synthetics_tests = [
    {
      name      = "Private Location Connectivity"
      public_id = datadog_synthetics_test.private_location_connectivity.public_id
    }
  ]
}

resource "datadog_synthetics_test" "private_location_connectivity" {
  name    = "cdap-${var.env}-private-location-connectivity"
  type    = "api"
  subtype = "tcp"
  status  = "live"

  request_definition {
    host = "api.ddog-gov.com"
    port = 443
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = "2000"
  }

  locations = [
    one([
      for location_id, location in data.datadog_synthetics_locations.all.locations :
      location_id
      if startswith(lower(location), local.synthetics_location_prefix)
    ])
  ]

  options_list {
    tick_every = 60
  }

  tags = ["environment:${var.env}", "app:cdap", "managed-by:tofu"]
}
