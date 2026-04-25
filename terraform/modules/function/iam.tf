data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

data "aws_iam_role" "admin" {
  name = "ct-ado-bcda-application-admin"
}

data "aws_iam_role" "dasg_admin" {
  name = "ct-ado-dasg-application-admin"
}

data "aws_iam_policy_document" "function_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  # Allow access from GitHub-hosted runners via OIDC for integration tests
  dynamic "statement" {
    for_each = length(var.github_actions_repos) > 0 ? [1] : []
    content {
      actions = ["sts:AssumeRoleWithWebIdentity", "sts:TagSession"]
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
        values   = var.github_actions_repos
      }
    }
  }

  # Allow access from admin role for manual checks
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn, data.aws_iam_role.dasg_admin.arn]
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "default_function" {
  dynamic "statement" {
    for_each = length(var.ssm_parameter_paths) > 0 ? [1] : []
    content {
      sid = "SSMParameterRead"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
      ]
      resources = var.ssm_parameter_paths
    }
  }

  statement {
    sid = "VPCNetworkingENI"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeNetworkInterfaces",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogsWrite"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.function.arn}:*"]
  }

  statement {
    sid = "KMSKeyAccess"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = concat(
      [data.aws_kms_alias.kms_key.target_key_arn],
      var.extra_kms_key_arns
    )
  }
}

resource "aws_iam_role" "function" {
  name = "${var.name}-function"
  path = "/delegatedadmin/developer/"

  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/cms-cloud-admin/developer-boundary-policy"

  assume_role_policy = data.aws_iam_policy_document.function_assume_role.json
}

resource "aws_iam_role_policy" "default_function" {
  name   = "default-function"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.default_function.json
}

resource "aws_iam_role_policy" "extra_policies" {
  for_each = var.function_role_inline_policies

  name   = each.key
  role   = aws_iam_role.function.id
  policy = each.value
}

# Allow CICD management outside of Tofu runs
data "aws_iam_policy_document" "cicd_manage_lambda_objects" {
  statement {
    sid = "CICDZipUpload"
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionTagging",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectTagging",
    ]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/delegatedadmin/developer/${var.app}-${var.env}-github-actions",
      ]
    }

    resources = [
      module.zip_bucket.arn,
      "${module.zip_bucket.arn}/*",
    ]
  }
}
