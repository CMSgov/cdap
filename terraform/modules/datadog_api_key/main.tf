resource "datadog_api_key" "this" {
  name = "${var.app}-${var.env}-${var.used_for}"
}

resource "aws_ssm_parameter" "datadog_api_key" {
  name        = "/${var.app}/${var.env}/datadog/${var.used_for}/api_key"
  tier        = "Intelligent-Tiering"
  description = "Managed by CDAP. ${var.used_for} API key for ${var.app} in ${var.env}."
  value       = datadog_api_key.this.key
  type        = "SecureString"
  key_id      = data.aws_kms_alias.primary.id
}

data "aws_kms_alias" "primary" {
  name = "alias/${var.app}-${var.env}"
}
