locals {
  provider_domain = "token.actions.githubusercontent.com"
  repos = {
    ab2d = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/ab2d-website:*",
      "repo:CMSgov/ab2d:*",
    ]
    bcda = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/bcda-app:*",
      "repo:CMSgov/bcda-ssas-app:*",
      "repo:CMSgov/bcda-static-site:*",
    ]
    dpc = [
      "repo:CMSgov/cdap:*",
      "repo:CMSgov/dpc-app:*",
      "repo:CMSgov/dpc-static-site:*",
    ]
    cdap = [
      "repo:CMSgov/cdap:*",
    ]
  }

}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_role" "admin" {
  name = "ct-ado-bcda-application-admin"
}

data "aws_iam_policy_document" "github_actions_role_assume" {
  # Allow access from the admin role
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn]
    }
  }

  # Allow access from GitHub-hosted runners via OIDC
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

data "aws_iam_policy" "poweruser_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

# This path delegatedadmin/developer is no longer required but we are keeping it for continuation of service
resource "aws_iam_role" "github_actions" {
  name = "${var.app}-${var.env}-github-actions"
  path = "/delegatedadmin/developer/"

  assume_role_policy   = data.aws_iam_policy_document.github_actions_role_assume.json
  permissions_boundary = data.aws_iam_policy.poweruser_boundary.arn
}

locals {
  github_actions_policies = merge(
    {
      compute       = data.aws_iam_policy_document.github_actions_compute.json
      networking    = data.aws_iam_policy_document.github_actions_networking.json
      storage       = data.aws_iam_policy_document.github_actions_storage.json
      security      = data.aws_iam_policy_document.github_actions_security.json
      observability = data.aws_iam_policy_document.github_actions_observability.json
    },
    var.app == "cdap" ? {
      cdap = data.aws_iam_policy_document.github_actions_cdap.json
    } : {}
  )
}

resource "aws_iam_policy" "github_actions" {
  for_each = local.github_actions_policies

  name   = "${var.app}-${var.env}-github-actions-${each.key}"
  path   = "/delegatedadmin/developer/"
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each   = { for k, v in aws_iam_policy.github_actions : k => v.arn }
  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}