data "datadog_synthetics_locations" "test" {}

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

  locations = [
    one([
      for location_id, location in data.datadog_synthetics_locations.test.locations :
      location_id
      if startswith(lower(location), "cdap-non-prod") # for prod: "cdap-prod"
    ])
  ]

  options_list {
    tick_every = 60
  }

  tags = ["environment:test", "app:cdap", "managed-by:tofu"]
}
