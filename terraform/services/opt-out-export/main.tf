locals {
  full_name = "${var.app}-${var.env}-opt-out-export"
  bfd_env   = var.env == "prod" ? "prod" : "test"
}

data "aws_ssm_parameter" "bfd_account" {
  name = "/bfd/account-id"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/bfd-${local.bfd_env}-eft-${var.app}-bucket-role"]
  }
}

module "opt_out_export_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Exports data files to a BFD bucket for opt-out"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  schedule_expression = "cron(0 3 ? * * *)"
  schedule_payload    = "{\"bucket\":\"bfd-${local.bfd_env}-eft\"}"

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-export"
  }
}
