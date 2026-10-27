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
