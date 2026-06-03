data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.provider_domain}"
}

locals {
  ssm_parameter_arns = [
    for path in var.ssm_parameter_paths :
    "arn:aws:ssm:${var.platform.primary_region.name}:${var.platform.account_id}:parameter${path}"
  ]
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

  # Allow access from admin role for manual checks, additional assume roles for config extension
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = concat(
        [
          data.aws_iam_role.admin.arn,
          data.aws_iam_role.dasg_admin.arn,
        ],
        var.additional_admin_role_arns
      )
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "dd_api_key" {
  name = "/${local.app}/${local.env}/datadog/agents/api_key"
}

data "aws_iam_policy_document" "default_function" {
  dynamic "statement" {
    for_each = length(local.ssm_parameter_arns) > 0 ? [1] : []
    content {
      sid = "SSMParameterRead"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
      ]
      resources = concat(
        local.ssm_parameter_arns,
        [data.aws_ssm_parameter.dd_api_key.arn]
      )
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
      [var.platform.kms_alias_primary.target_key_arn],
      var.extra_kms_key_arns
    )
  }
}

resource "aws_iam_role" "function" {
  name = "${local.full_name_string}-function"
  path = "/delegatedadmin/developer/"

  assume_role_policy = data.aws_iam_policy_document.function_assume_role.json
}

resource "aws_iam_role_policy" "default_function" {
  name   = "${local.full_name_string}-default"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.default_function.json
}

resource "aws_iam_role_policy" "extra_policies" {
  for_each = var.function_role_inline_policies

  name   = "${local.app}-${local.env}-${each.key}"
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
        "arn:aws:iam::${var.platform.account_id}:role/delegatedadmin/developer/${local.app}-${local.env}-github-actions",
      ]
    }

    resources = [
      module.zip_bucket.arn,
      "${module.zip_bucket.arn}/*",
    ]
  }
}
