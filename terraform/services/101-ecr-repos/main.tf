locals {
  # Get the config file per environment we manage 
  app_configs = {
    for f in fileset("${path.module}/config", "*/*.yml") :
    dirname(f) => {
      app    = dirname(f)
      env    = trimsuffix(basename(f), ".yml")
      config = try(coalesce(yamldecode(file("${path.module}/config/${f}")), {}), {})
    }
    if trimsuffix(basename(f), ".yml") == var.env
  }

  # get each key value pair from the config 
  all_repos = {
    for pair in flatten([
      for config_key, config_data in local.app_configs : [
        for svc in try(config_data.config.services, []) : {
          key     = "${config_data.app}/${svc.name}"
          app     = config_data.app
          service = svc.name

          tag_rules            = try(svc.tag_rules, [])
          untagged_expiry_days = try(svc.untagged_expiry_days, null)
          account_id_paths     = try(svc.account_id_paths, [])
        }
      ]
    ]) : pair.key => pair
  }

  # limit ssm lookups if multiple repositories are shared with the same accounts lookup just once
  all_account_id_paths = toset(flatten([for repo in local.all_repos : repo.account_id_paths]))

  cdap_env = contains(["sandbox", "prod"], var.env) ? "prod" : "test"
}


data "aws_ssm_parameter" "external_account_id" {
  for_each        = local.all_account_id_paths
  name            = each.value
  with_decryption = true
}

# One platform module per app, each has its own KMS key
module "platform" {
  for_each = local.app_configs

  source    = "../../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = each.value.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service     = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
}

# One ECR repo per service, using the correct platform instance for its app
module "ecr_repo" {
  for_each = local.all_repos

  source   = "../../modules/ecr_repo"
  platform = module.platform[each.value.app]
  service  = each.value.service

  tag_rules            = each.value.tag_rules
  untagged_expiry_days = each.value.untagged_expiry_days

  external_account_share = [
    for path in each.value.account_id_paths : data.aws_ssm_parameter.external_account_id[path].value
  ]
}
