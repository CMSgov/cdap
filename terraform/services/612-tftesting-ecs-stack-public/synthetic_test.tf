module "datadog_synthetics" {
  source = "../../modules/datadog_synthetics"

  app                  = "cdap"
  env                  = var.platform.env
  notify               = "@webhook-cdap"
  min_failure_duration = 0
  shadow_mode          = false
  accept_self_signed = true


  tests = [
    {
      name    = "tftesting-ecs-stack-public integration"
      type    = "api"
      subtype = "http"
      status  = "live"

      request_definition = {
        method = "GET"
        url    = "https://${module.alb.dns_name}/integration-test"
      }

      assertions = [
        {
          type     = "statusCode"
          operator = "is"
          target   = "200"
        },
        {
          type     = "body"
          operator = "contains"
          target   = "pong"
        },
        {
          type     = "body"
          operator = "contains"
          target   = "tftesting-b"
        },
        {
          type     = "responseTime"
          operator = "lessThan"
          target   = "5000"
        }
      ]

      tick_every           = 300
      min_failure_duration = 0
      use_private_location = true

      tags = ["test:integration", "service:tftesting-a"]
    }
  ]
}
