resource "aws_quicksight_account_settings" "this" {
    aws_account_id                 = local.account_id
    default_namespace              = "default"
    termination_protection_enabled = true
}

resource "aws_quicksight_ip_restriction" "this" {
  # IP restrictions temporarily disabled due to Zscaler access issues
  enabled = false #length(local.ip_restrictions) > 0

  ip_restriction_rule_map = local.ip_restrictions

  depends_on = [
    module.sops
  ]
}
