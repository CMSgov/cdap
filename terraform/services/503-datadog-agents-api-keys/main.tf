locals {
  config_file_path = "${path.module}/config/${var.env}/${var.app}.yml"
  config_data      = fileexists(local.config_file_path) ? yamldecode(file(local.config_file_path)) : null
}
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
