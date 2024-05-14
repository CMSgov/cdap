
locals {
  repos = {
    ab2d = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/ab2d-events:*",
      "repo:CMSgov/ab2d-lambdas:*",
      "repo:CMSgov/ab2d:*",
    ]
    bcda = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/bcda-app:*",
    ]
    dpc = [
      "repo:CMSgov/ab2d-bcda-dpc-platform:*",
      "repo:CMSgov/dpc-app:*",
    ]
  }
  admin_app = var.app == "dpc" ? "bcda" : var.app
}

resource "aws_ssm_parameter" "snyk_integration_role_arn" {
  name  = "/${var.app}-snyk/role-arn"
  type  = "String"
  value = aws_iam_role.snyk.arn
}


data "aws_ssm_parameter" "snyk_integration_role_arn" {
  name = "/snyk-integration/role-arn"
}

data "aws_iam_role" "admin" {
  name = "ct-ado-${local.admin_app}-application-admin"
}

data "aws_iam_policy_document" "snyk_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type = "AWS"
      identifiers = [
        data.aws_ssm_parameter.snyk_integration_role_arn.value,
        data.aws_iam_role.admin.arn,
      ]
    }
  }

  statement {
    sid       = "SnykAllowPull"
    effect    = "Allow"
    actions   = [
      "ecr:GetLifecyclePolicyPreview",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:ListImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam:::user/ecr-integration-user"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["f3cbda90-da90-411a-984c-4e275489ecd1"]
    }
  }
}

data "aws_iam_policy" "poweruser_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

resource "aws_iam_role" "snyk" {
  name                 = "${var.app}-${var.env}-snyk"
  path                 = "/delegatedadmin/developer/"
  assume_role_policy   = data.aws_iam_policy_document.snyk_role_policy.json
  permissions_boundary = data.aws_iam_policy.poweruser_boundary.arn
}
