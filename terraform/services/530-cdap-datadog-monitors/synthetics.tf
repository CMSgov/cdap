module "synthetics" {
  source = "../../modules/datadog_synthetics"

  app = "cdap"
  env = var.env

  notify               = module.common_datadog_monitors.notify
  shadow_mode          = local.monitor_config.shadow_mode
  min_failure_duration = local.monitor_config.synthetics.min_failure_duration

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
