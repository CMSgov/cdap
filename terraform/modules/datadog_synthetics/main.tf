resource "datadog_synthetics_test" "this" {
  for_each = var.tests

  name    = "${var.app}-${var.env}-${each.value.name}"
  type    = each.value.type
  subtype = each.value.subtype
  status  = each.value.status

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

  locations = each.value.use_private_location ? [local.private_location_id] : local.non_private_location_ids

  dynamic "lifecycle" {
    for_each = each.value.use_private_location ? [1] : []
    precondition {
      condition     = local.private_location_id != null
      error_message = "No Datadog private location found with prefix '${local.location_prefix}'. Verify the private location agent is registered for this environment."
    }
  }

  options_list {
    tick_every = each.value.tick_every
  }

  tags = concat(local.base_tags, each.value.tags)
}
