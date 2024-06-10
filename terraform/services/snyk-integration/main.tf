data "aws_ssm_parameter" "external_id" {
  name = local.external_id_param
}

data "aws_ssm_parameter" "ecr_integration_user" {
  name = "/snyk-integration/ecr-integration-user"
}

locals {
  external_id_param = var.app == "ab2d" ? "/snyk-integration/ab2d-external-id" : "/snyk-integration/bcda-external-id"
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
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
  statement {
    sid    = "SnykAllowPull"
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
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "snyk_pull" {
  name        = "snyk-pull-ecr"
  path        = "/delegatedadmin/developer/"
  description = "Policy for Snyk to pull images from ECR"
  policy      = data.aws_iam_policy_document.snyk_pull.json
}

resource "aws_iam_role" "snyk" {
  name                 = "snyk"
  path                 = "/delegatedadmin/developer/"
  assume_role_policy   = data.aws_iam_policy_document.snyk_trust.json
  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
}

resource "aws_iam_role_policy_attachment" "snyk_pull_policy_attachment" {
  role       = aws_iam_role.snyk.name
  policy_arn = aws_iam_policy.snyk_pull.arn
}
