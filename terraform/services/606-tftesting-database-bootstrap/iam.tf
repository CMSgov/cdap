data "aws_iam_policy_document" "db_connect_migrator" {
  statement {
    sid     = "AllowIamAuthAsMigrator"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_ssm_parameter.cluster_resource_id.value}/tftesting_migrator"
    ]
  }
}

resource "aws_iam_policy" "db_connect_migrator" {
  name        = "${local.aurora_app_name}-db-connect-migrator"
  description = "Allows IAM database authentication as tftesting_migrator. Used only to run schema migrations against the tftesting cluster."
  policy      = data.aws_iam_policy_document.db_connect_migrator.json
}

resource "aws_iam_role_policy_attachment" "db_connect_migrator_ci" {
  role       = data.aws_iam_role.ci.name
  policy_arn = aws_iam_policy.db_connect_migrator.arn
}

# Direct human IAM database access. Same shape as the CI role with a
# dedicated role, a narrow trust policy naming exactly who can assume it,
# and one narrow permission.
data "aws_iam_policy" "developer_boundary_policy" {
  count = var.enable_human_database_access ? 1 : 0
  name  = "developer-boundary-policy"
}

data "aws_iam_policy_document" "human_db_access_assume_role" {
  count = var.enable_human_database_access ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [for r in data.aws_iam_role.human_access_admins : r.arn]
    }
  }
}

resource "aws_iam_role" "human_db_access" {
  count                = var.enable_human_database_access ? 1 : 0
  name                 = "${local.aurora_app_name}-human-db-access"
  path                 = "/delegatedadmin/developer/"
  assume_role_policy   = data.aws_iam_policy_document.human_db_access_assume_role[0].json
  permissions_boundary = data.aws_iam_policy.developer_boundary_policy[0].arn
}

data "aws_iam_policy_document" "db_connect_human" {
  count = var.enable_human_database_access ? 1 : 0

  statement {
    sid     = "AllowIamAuthAsTftestingHuman"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_ssm_parameter.cluster_resource_id.value}/tftesting_human"
    ]
  }
}

resource "aws_iam_policy" "db_connect_human" {
  count       = var.enable_human_database_access ? 1 : 0
  name        = "${local.aurora_app_name}-db-connect-human"
  description = "Allows the tftesting-human-db-access role to authenticate directly to Postgres as tftesting_human."
  policy      = data.aws_iam_policy_document.db_connect_human[0].json
}

resource "aws_iam_role_policy_attachment" "db_connect_human" {
  count      = var.enable_human_database_access ? 1 : 0
  role       = aws_iam_role.human_db_access[0].name
  policy_arn = aws_iam_policy.db_connect_human[0].arn
}