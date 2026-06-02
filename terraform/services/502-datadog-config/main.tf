resource "datadog_monitor_config_policy" "env_tag" {
  policy_type = "tag"
  tag_policy {
    tag_key          = "environment"
    tag_key_required = true
    valid_tag_values = ["dev", "test", "stage", "sandbox", "prod"]
  }
}
