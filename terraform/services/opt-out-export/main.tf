locals {
  full_name = "${var.app}-${var.env}-opt-out-export"
  bfd_env = var.env == "prod" ? "prod" : "test"
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

module "opt_out_export_lambda" {
  source = "../../modules/lambda"

  app = var.app
  env = var.env

  function_name        = local.full_name
  function_description = "Exports data files to a BFD bucket for opt-out"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  lambda_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-export"
  }
}
