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
}
