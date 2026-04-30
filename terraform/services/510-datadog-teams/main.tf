resource "datadog_team" "this" {
  for_each    = toset(var.app_teams)
  description = "Team that implements and manages ${each.key}"
  handle      = lower(each.key)
  name        = "${upper(each.key)} Team"
}

module "standards" {
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = "prod"
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${path.module}/"
  service      = replace(path.module, "/[0-9]/", "")
  ssm_root_map = { datadog = "/cdap/prod/datadog/cicd" }
}
