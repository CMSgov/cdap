module "synthetics" {
  source = "../../modules/datadog_synthetics"

  app = "cdap"
  env = var.env

  tests = {
    private_location_connectivity = {
      name    = "private-location-connectivity"
      subtype = "tcp"
      request_definition = {
        host = "api.ddog-gov.com"
        port = 443
      }
      assertions = [
        {
          type     = "responseTime"
          operator = "lessThan"
          target   = "2000"
        }
      ]
    }
  }
}
