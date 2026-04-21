resource "datadog_monitor_config_policy" "env_tag" {
  policy_type = "tag"
  tag_policy {
    tag_key          = "environment"
    tag_key_required = true
    valid_tag_values = ["dev", "test", "stage", "sandbox", "prod"]
  }
}

module "platform" {
  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = "prod"
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/cdap/prod/datadog/cicd/" }
}
