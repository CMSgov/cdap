locals {
  app            = "cdap"
  env            = "mgmt"
  service        = "insights"
  service_prefix = "${local.app}-${local.env}-${local.service}"
  account_id     = module.standards.aws_caller_identity.id

  kms_key_aliases = {
    kms_alias_primary   = data.aws_kms_alias.primary,
    kms_alias_secondary = data.aws_kms_alias.secondary
  }

  cdap_ssm = zipmap(
    data.aws_ssm_parameters_by_path.cdap.names,
    data.aws_ssm_parameters_by_path.cdap.values
  )

  ip_restrictions = jsondecode(lookup(nonsensitive(local.cdap_ssm), "/cdap/mgmt/insights/sensitive/ip-restrictions", "{}"))
}

module "standards" {
  source = "../../modules/standards" #TODO: Update with appropriate reference

  app         = local.app
  env         = local.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/insights/mgmt"
  service     = local.service
  providers   = { aws = aws, aws.secondary = aws.secondary }
}

data "aws_kms_alias" "primary" {
  name = "alias/${local.app}-${local.env}"
}

data "aws_kms_alias" "secondary" {
  provider = aws.secondary
  name     = "alias/${local.app}-${local.env}"
}

module "sops" {
  source = "../../modules/sops" #TODO: Update with appropriate reference

  platform = merge(module.standards, local.kms_key_aliases)
}

data "aws_ssm_parameters_by_path" "cdap" {
  path = "/cdap"
  recursive = true
  with_decryption = true
}
