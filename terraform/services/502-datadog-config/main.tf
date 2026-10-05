resource "datadog_monitor_config_policy" "env_tag" {
  policy_type = "tag"
  tag_policy {
    tag_key          = "environment"
    tag_key_required = true
    valid_tag_values = ["dev", "test", "stage", "sandbox", "prod"]
  }
}

resource "datadog_sensitive_data_scanner_group" "main" {
  name        = "Shared sensitive data scanning group"
  description = "Group shared by all teams."
  filter {
    query = "*"
  }
  is_enabled   = true
  product_list = ["rum", "events", "apm"]

  samplings {
    product = "rum"
    rate    = 100
  }

  samplings {
    product = "events"
    rate    = 100
  }

  samplings {
    product = "apm"
    rate    = 100
  }
}
