locals {
  provider_domain = "token.actions.githubusercontent.com"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_ssm_parameter" "github_runner_role_arn" {
  name = "/github-runner/role-arn"
}

data "aws_iam_policy_document" "github_actions_deploy_assume" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_ssm_parameter.github_runner_role_arn.value]
    }
  }

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
      values   = ["repo:CMSgov/*"]
    }
  }
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_iam_policy_document" "github_actions_deploy_inline" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${var.app}-${var.env}-github-actions-deploy"
  path = "/delegatedadmin/developer/"

  assume_role_policy = data.aws_iam_policy_document.github_actions_deploy_assume.json

  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn

  inline_policy {
    name   = "github-actions-deploy"
    policy = data.aws_iam_policy_document.github_actions_deploy_inline.json
  }
}
