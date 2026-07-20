data "datadog_synthetics_locations" "all" {}

locals {
  base_tags = [
    "application:${var.app}",
    "environment:${var.env}",
    "managed-by:tofu",
    var.shadow_mode ? "shadow-mode:true" : "shadow-mode:false",
  ]
  location_prefix = contains(["sandbox", "prod"], var.env) ? "cdap-prod" : "cdap-non-prod"

  private_location_id = one([
    for location_id, location in data.datadog_synthetics_locations.all.locations :
    location_id
    if startswith(lower(location), local.location_prefix)
  ])
}
