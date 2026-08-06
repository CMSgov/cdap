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

  statement {
    sid = "KmsUsage"
    actions = [
      "kms:CreateAlias",
      "kms:CreateKey",
      "kms:ListAliases",
      "kms:TagResource",
    ]
    resources = ["*"] # account-level, must be *
  }

  # KMS - Specific Keys (app-aware)
  statement {
    sid = "KmsSpecificKeyUsage"
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListGrants",
      "kms:ListResourceTags",
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

  # Write — own namespace only
  # TODO: enforce once SSM path conventions are confirmed
  statement {
    sid = "SsmWrite"
    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
    ]
    resources = [
      "*", # arn:aws:ssm:*:*:parameter/${var.app}/${var.env}/*"
    ]
  }

  # Read — own namespace
  # TODO: enforce once SSM path conventions are confirmed
  statement {
    sid = "SsmReadOwn"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource",
    ]
    resources = [
      "*", # arn:aws:ssm:*:*:parameter/${var.app}/${var.env}/*
    ]
  }

  # Read — CDAP shared tokens
  # TODO: enforce once CDAP shared SSM path conventions are confirmed
  # Expected paths: /cdap/${module.standards.cdap_env}/commmon/{app}/* and /cdap/${module.standards.cdap_env}/common/global/*
  statement {
    sid = "SsmReadCdapShared"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]
    resources = [
      "*"
    ]
  }

  # Cannot be resource-scoped — must stay glob
  statement {
    sid = "SsmUnscoped"
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
