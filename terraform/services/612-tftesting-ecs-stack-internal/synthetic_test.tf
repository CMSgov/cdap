# module "datadog_synthetics" {
#   source = "../../modules/datadog_synthetics"
#
#   app                  = module.platform.app
#   env                  = module.platform.env
#   notify               = "@webhook-slack-${module.platform.app}"
#   min_failure_duration = 60
#
#   tests = [
#     {
#       name    = "${module.platform.service}-alb-health"
#       subtype = "http"
#       status  = "live"
#
#       request_definition = {
#         method = "GET"
#         url    = "https://${module.acm.internal_domain}/health"
#       }
#
#       assertions = [
#         {
#           type     = "statusCode"
#           operator = "is"
#           target   = "200"
#         },
#         {
#           type     = "responseTime"
#           operator = "lessThan"
#           target   = "5000"
#         }
#       ]
#
#       use_private_location = true
#       tick_every           = 60
#     }
#   ]
# }
