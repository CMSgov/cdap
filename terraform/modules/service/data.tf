data "aws_ssm_parameter" "secrets" {
  for_each = { for secret in try(var.container_secrets, []) : secret.name => secret if secret != null }

  # valueFrom may be a full ARN or a plain path — normalize to path
  name = can(regex("^arn:aws:ssm:", each.value.valueFrom)) ? (
    # Extract the parameter name from the ARN
    # ARN format: arn:aws:ssm:region:account:parameter/path/to/param
    replace(
      regex("parameter(.+)$", each.value.valueFrom)[0],
      "parameter",
      ""
    )
  ) : each.value.valueFrom
}

data "aws_ram_resource_share" "pace_ca" {
  resource_owner = "OTHER-ACCOUNTS"
  name           = "pace-ca-g1"
}

data "aws_ssm_parameter" "datadog_api_key" {
  name = "/${var.platform.app}/${var.platform.env}/datadog/agents/api_key"
}
