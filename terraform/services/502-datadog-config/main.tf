resource "datadog_monitor_config_policy" "env_tag" {
  policy_type = "tag"
  tag_policy {
    tag_key          = "environment"
    tag_key_required = true
    valid_tag_values = ["dev", "test", "stage", "sandbox", "prod"]
  }
}

data "aws_ssm_parameter" "cdap_datadog_api_key" {
  name = "/cdap/prod/datadog/cicd/api_key"
}

data "aws_ssm_parameter" "cdap_datadog_application_key" {
  name = "/cdap/prod/datadog/cicd/application_key"
}
