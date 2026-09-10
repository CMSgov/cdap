module "datadog_synthetics" {
  source = "../../modules/datadog_synthetics"

  app                  = module.platform.app
  env                  = module.platform.env
  notify               = "@webhook-slack-${module.platform.app}"
  min_failure_duration = 60
  enabled              = true
  allow_insecure       = true

  tests = [
    {
      name    = "${module.platform.service}-service-connect-roundtrip"
      subtype = "http"
      status  = "live"

      request_definition = {
        method = "GET"
        url    = "https://${module.acm.internal_domain}/integration-test"
      }

      assertions = [
        { type = "statusCode", operator = "is", target = "200" },
        { type = "body", operator = "contains", target = "\"status\": \"ok\"" },
        { type = "body", operator = "contains", target = "pong from" }
      ]
      use_private_location = true
      tick_every           = 60
    }
  ]
}
