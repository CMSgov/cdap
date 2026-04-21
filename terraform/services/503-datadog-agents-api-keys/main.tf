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

data "aws_ssm_parameter" "cdap_datadog_api_key" {
  name = "/cdap/${local.cdap_env}/datadog/cicd/api_key"
}

data "aws_ssm_parameter" "cdap_datadog_application_key" {
  name = "/cdap/${local.cdap_env}/datadog/cicd/application_key"
}

module "standards" {
  source = "../../modules/standards"

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/datadog-agents-api-keys"
  service     = "datadog"
  providers   = { aws = aws, aws.secondary = aws.secondary }
}
