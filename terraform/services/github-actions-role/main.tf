data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "AWS"
      identifiers = [var.runner_arn]
    }
  }

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

data "aws_iam_policy_document" "github_actions_inline" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions"
  path = "/delegatedadmin/developer/"

  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
  assume_role_policy   = data.aws_iam_policy_document.github_actions_assume.json

  inline_policy {
    name   = "github-actions"
    policy = data.aws_iam_policy_document.github_actions_inline.json
  }
}
