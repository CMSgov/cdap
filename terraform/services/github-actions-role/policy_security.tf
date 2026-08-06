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
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAccountAliases",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListOpenIDConnectProviders",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
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
  # Write — own namespace only
  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
    ]
    resources = [
      "*", # scope to something like arn:aws:ssm:*:*:parameter/${var.app}/${var.env}/*
    ]
  }

  # Read — own namespace or broad
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
    ]
    resources = [
      "*", # scope to something like arn:aws:ssm:*:*:parameter/${var.app}/${var.env}/*
    ]
  }

  # Read — CDAP shared tokens only
  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "*", # scope to CDAP managed paths arn:aws:ssm:*:*:parameter/cdap/${module.standards.cdap_env} (sandbox and test variance) /common/${var.app}/*", "arn:aws:ssm:*:*:parameter/cdap/${module.standards.cdap_env}/common/global/*",
    ]
  }

  # Cannot be resource-scoped — must stay *
  statement {
    actions = [
      "ssm:DescribeParameters",
      "ssm:StartSession",
      "ssm:TerminateSession",
    ]
    resources = ["*"]
  }

  # STS
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}
