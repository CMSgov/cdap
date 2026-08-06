locals {
  # FIXME Drop account_env_old when we are fully migrated to cdap-test and cdap-prod
  # Verify scope of use of bcda-prod and bcda-test before removing
  # Verify what these other KMS keys are used for and if access can be restricted to cdap scope
  account_env_old = contains(["dev", "test"], var.env) ? "bcda-test" : "bcda-prod"
  account_env     = contains(["dev", "test"], var.env) ? "cdap-test" : "cdap-prod"
}

# KMS keys needed for IAM policy
data "aws_kms_alias" "environment_key" {
  name = "alias/${var.app}-${var.env}"
}

data "aws_kms_alias" "account_env_old" {
  name = "alias/${local.account_env_old}"
}

data "aws_kms_alias" "account_env_old_secondary" {
  provider = aws.secondary
  name     = "alias/${local.account_env_old}"
}

data "aws_kms_alias" "account_env" {
  name = "alias/${local.account_env}"
}

data "aws_kms_alias" "account_env_secondary" {
  provider = aws.secondary
  name     = "alias/${local.account_env}"
}

# Additional KMS keys
## FIXME reduce the scope of these keys in collaboration with teams

locals {
  env_config             = yamldecode(file("${path.module}/config/${var.app}/${var.env}.yml"))
  additional_kms_aliases = try(local.env_config.additional_kms, [])
}

data "aws_kms_alias" "additional_kms" {
  for_each = toset(local.additional_kms_aliases)
  name     = "alias/${each.key}"
}

# TODO : check if all other KMS keys can be removed or if they're used anywhere?
data "aws_iam_policy_document" "github_actions_security" {
  # IAM
  statement {
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:Get*",
      "iam:List*",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["*"]
  }

  # KMS - General
  statement {
    sid = "KmsUsage"
    actions = [
      "kms:CreateAlias",
      "kms:CreateKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:TagResource",
    ]
    resources = ["*"]
  }

  # KMS - Specific Keys (app-aware)
  statement {
    sid = "KmsSpecificKeyUsage"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:List*",
      "kms:PutKeyPolicy",
      "kms:ReEncrypt*",
    ]
    resources = concat(
      values(data.aws_kms_alias.additional_kms)[*].target_key_arn,
      [data.aws_kms_alias.environment_key.target_key_arn],
      [data.aws_kms_alias.account_env_old.target_key_arn],
      [data.aws_kms_alias.account_env_old_secondary.target_key_arn],
      [data.aws_kms_alias.account_env.target_key_arn],
      [data.aws_kms_alias.account_env_secondary.target_key_arn],
    )
  }

  # Systems Manager
  statement {
    actions = [
      "ssm:AddTagsToResource",
      "ssm:DeleteParameter",
      "ssm:DescribeParameters",
      "ssm:GetParameter*",
      "ssm:ListTagsForResource",
      "ssm:PutParameter",
      "ssm:StartSession",
      "ssm:TerminateSession",
    ]
    resources = ["*"] # FIXME This should be refined by paths for get vs create based on what paths teams own and per env
  }

  # STS
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}
