data "aws_ssm_parameter" "secrets" {
  for_each = nonsensitive({
    for index, secret in coalesce(var.container_secrets, []) :
    tostring(index) => secret
    if secret != null
  })

  name = can(regex("^arn:aws:ssm:", each.value.valueFrom)) ? regex("parameter(/[^:]+)$", each.value.valueFrom)[0] : each.value.valueFrom
}

data "aws_ram_resource_share" "pace_ca" {
  resource_owner = "OTHER-ACCOUNTS"
  name           = "pace-ca-g1"
}

data "aws_ssm_parameter" "datadog_api_key" {
  name = "/${var.platform.app}/${var.platform.env}/datadog/agents/api_key"
}

data "aws_ssm_parameter" "datadog_private_location_sg" {
  count = (var.enable_datadog_synthetics_ingress && length(var.security_groups) == 0) ? 1 : 0
  name  = "/cdap/${var.platform.env}/datadog/nonsensitive/private_location_task_security_group_id"
}
