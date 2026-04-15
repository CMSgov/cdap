locals {
  env_suffix = var.name_suffix == "cicd" ? (contains(
  ["sandbox", "prod"], var.env) ? "non-prod" : "prod") : var.env
}

resource "datadog_api_key" "this" {
  name = "${var.app}-${locals.env_suffix}-${var.name_suffix}"
}

