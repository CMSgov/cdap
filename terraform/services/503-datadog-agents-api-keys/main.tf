#--------------
### API KEY ### Used for agents, Associated with the organization
#--------------
module "datadog_api_key" {
  source   = "../../modules/datadog_api_key"
  app      = var.app
  env      = var.env
  used_for = "agents"
}

# The CDAP api key and application keys manage agent keys

locals {
  cdap_env = contains(["sandbox", "prod"], var.env) ? "prod" : "test"
}


module "standards" {
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = var.app
  env          = var.env
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/${var.app}/${var.env}/datadog/cicd/" }
}
