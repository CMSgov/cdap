data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

#
# Runner role section
#

data "aws_iam_policy_document" "runner_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.runner_arn]
    }
  }
}

data "aws_iam_policy_document" "runner_inline" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "runner" {
  name = "github-actions-runner"
  path = "/delegatedadmin/developer/"

  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
  assume_role_policy   = data.aws_iam_policy_document.runner_assume.json

  inline_policy {
    name   = "all-within-boundary"
    policy = data.aws_iam_policy_document.runner_inline.json
  }
}

#
# OIDC role section
#

data "aws_iam_policy_document" "oidc_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:CMSgov/*"]
    }
  }
}

data "aws_iam_policy_document" "oidc_inline" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "oidc" {
  name = "github-actions-oidc"
  path = "/delegatedadmin/developer/"

  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
  assume_role_policy   = data.aws_iam_policy_document.oidc_assume.json

  inline_policy {
    name   = "all-within-boundary"
    policy = data.aws_iam_policy_document.oidc_inline.json
  }
}
