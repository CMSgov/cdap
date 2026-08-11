locals {
  # cdap-test manages dev + test
  # cdap-prod manges sandbox + prod
  managed_envs = var.app == "cdap" ? (
    contains(["dev", "test"], var.env) ? ["dev", "test"] : ["sandbox", "prod"]
  ) : []

  managed_apps = ["ab2d", "bcda", "dpc", "cdap"]

  # Load all config files for managed apps/envs and collect their KMS aliases
  cdap_managed_kms_aliases = var.app == "cdap" ? flatten([
    for app in local.managed_apps : [
      for env in local.managed_envs : try(
        yamldecode(
          file("${path.module}/config/${app}/${env}.yml")
        ).additional_kms,
        []
      )
    ]
  ]) : []
}

data "aws_kms_alias" "cdap_managed_kms" {
  for_each = toset(local.cdap_managed_kms_aliases)
  name     = "alias/${each.key}"
}

data "aws_iam_policy_document" "github_actions_cdap" {
  # CodeBuild - managed by CDAP terraservice
  statement {
    actions = [
      "codebuild:BatchGetProjects",
      "codebuild:CreateProject",
      "codebuild:CreateWebhook",
      "codebuild:DeleteProject",
      "codebuild:DeleteWebhook",
      "codebuild:List*",
      "codebuild:UpdateProject",
      "codebuild:UpdateProjectVisibility",
      "codebuild:UpdateWebhook",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KmsCreate"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:Describe*"
    ]
    resources = ["*"]
  }

  # FIXME CDAP manages all KMS keys so this permission could be broad
  # FIXME Deprecate the bcda key as the account environment key
  statement {
    sid = "KmsKeyAdmin"
    actions = [
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:TagResource",
    ]
    resources = length(data.aws_kms_alias.cdap_managed_kms) > 0 ? concat(
      values(data.aws_kms_alias.cdap_managed_kms)[*].target_key_arn,
      [data.aws_kms_alias.environment_key.target_key_arn],
      [data.aws_kms_alias.account_env_old.target_key_arn],
      [data.aws_kms_alias.account_env_old_secondary.target_key_arn],
      [data.aws_kms_alias.account_env.target_key_arn],
      [data.aws_kms_alias.account_env_secondary.target_key_arn],
    ) : ["*"]
  }

  # Secrets Manager - only CDAP uses this
  statement {
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteResourcePolicy",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
    ]
    resources = ["*"]
  }

  # Add other CDAP-only services here as needed...
}

resource "aws_iam_policy" "github_actions_cdap" {
  count  = var.app == "cdap" ? 1 : 0
  name   = "${var.app}-${var.env}-github-actions-cdap"
  path   = "/delegatedadmin/developer/"
  policy = data.aws_iam_policy_document.github_actions_cdap.json
}
