locals {
  full_name       = "${var.app}-${var.env}-opt-out-import"
  provider_domain = "token.actions.githubusercontent.com"
  repos = {
    ab2d = [
      "repo:CMSgov/ab2d-lambdas:*",
    ]
    bcda = [
      "repo:CMSgov/bcda-app:*",
    ]
    dpc = [
      "repo:CMSgov/dpc-app:*",
    ]
  }
}

data "aws_ssm_parameter" "bfd_bucket_role_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-bucket-role-arn"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [data.aws_ssm_parameter.bfd_bucket_role_arn.value]
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_policy_document" "allow_oidc" {
  # Allow access from GitHub-hosted runners via OIDC for integration tests
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sts:TagSession",
    ]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.provider_domain}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.provider_domain}:sub"
      values   = local.repos[var.app]
    }
  }
}

module "opt_out_import_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Ingests the most recent beneficiary opt-out list from BFD"

  handler = var.app == "ab2d" ? "gov.cms.ab2d.optout.OptOutHandler" : "bootstrap"
  runtime = var.app == "ab2d" ? "java11" : "provided.al2"

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
    allow-oidc         = data.aws_iam_policy_document.allow_oidc.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-opt-out-import"
  }
}

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/opt-out-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "opt_out_import_queue" {
  source = "../../modules/queue"

  name = local.full_name

  function_name = module.opt_out_import_function.name
  sns_topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
}
