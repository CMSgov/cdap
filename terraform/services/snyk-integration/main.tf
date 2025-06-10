locals {
  app = ["ab2d", "bcda", "dpc"]
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_ssm_parameter" "external_id" {
  name = "/snyk-integration/external-id"
}

data "aws_ssm_parameter" "ecr_integration_user" {
  name = "/snyk-integration/ecr-integration-user"
}

data "aws_iam_policy_document" "snyk_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_ssm_parameter.ecr_integration_user.value]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [data.aws_ssm_parameter.external_id.value]
    }
  }
}

data "aws_iam_policy_document" "snyk_pull" {
  for_each = toset(local.app)

  statement {
    sid    = "${each.key}SnykAllowPull"
    effect = "Allow"
    actions = [
      "ecr:GetLifecyclePolicyPreview",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:ListImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetRepositoryPolicy"
    ]
    resources = [
      "arn:aws:ecr:us-east-1:${data.aws_caller_identity.current.account_id}:repository/${each.key}-*"
    ]
  }
}

resource "aws_iam_role_policy" "snyk_pull" {
  for_each = toset(local.app)

  name   = "${each.key}-snyk-pull-ecr"
  role   = aws_iam_role.snyk[each.key].name
  policy = data.aws_iam_policy_document.snyk_pull[each.key].json
}

resource "aws_iam_role" "snyk" {
  for_each = toset(local.app)

  name                 = "${each.key}-snyk"
  path                 = "/delegatedadmin/developer/"
  assume_role_policy   = data.aws_iam_policy_document.snyk_trust.json
  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
}
