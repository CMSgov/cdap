resource "datadog_synthetics_test" "this" {
  for_each = { for m in var.tests : m.name => m }

  name    = "${var.app}-${var.env}-${each.value.name}"
  type    = each.value.type
  subtype = each.value.subtype
  status  = each.value.status
  message = "Synthetics test ${var.app}-${var.env}-${each.value.name} has failed. ${var.notify}"

  request_definition {
    host   = each.value.request_definition.host
    port   = each.value.request_definition.port
    method = each.value.request_definition.method
    url    = each.value.request_definition.url
  }

  dynamic "assertion" {
    for_each = each.value.assertions
    content {
      type     = assertion.value.type
      operator = assertion.value.operator
      target   = assertion.value.target
      property = assertion.value.property

      dynamic "targetjsonpath" {
        for_each = assertion.value.targetjsonpath != null ? [assertion.value.targetjsonpath] : []
        content {
          jsonpath    = targetjsonpath.value.jsonpath
          operator    = targetjsonpath.value.operator
          targetvalue = targetjsonpath.value.targetvalue
        }
      }
    }
  }

  locations = distinct(concat(
    each.value.use_private_location && local.private_location_id != null ? [local.private_location_id] : (!each.value.use_private_location ? local.non_private_location_ids : []),
    each.value.locations != null ? each.value.locations : []
  ))

  lifecycle {
    precondition {
      condition     = !each.value.use_private_location || local.private_location_id != null || (each.value.locations != null && length(each.value.locations) > 0)
      error_message = "No Datadog private location found with prefix '${local.location_prefix}'. Verify the private location agent is registered for this environment."
    }
  }

  options_list {
    tick_every           = each.value.tick_every
    monitor_name         = "[${upper(var.env)}] [${var.app}] Synthetics — ${each.value.name}"
    min_failure_duration = try(coalesce(each.value.min_failure_duration, var.min_failure_duration), null)
    min_location_failed  = each.value.min_location_failed
  }

  tags = concat(local.base_tags, each.value.tags)
}
