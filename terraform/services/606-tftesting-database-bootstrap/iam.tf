data "aws_iam_policy_document" "db_connect_migrator" {
  count = local.tftesting_cluster_exists ? 1 : 0

  statement {
    sid     = "AllowIamAuthAsMigrator"
    effect  = "Allow"
    actions = ["rds-db:connect"]
    resources = [
      "arn:aws:rds-db:${module.platform.primary_region.name}:${module.platform.account_id}:dbuser:${data.aws_ssm_parameter.cluster_resource_id[0].value}/tftesting_migrator"
    ]
  }
}

resource "aws_iam_policy" "db_connect_migrator" {
  count = local.tftesting_cluster_exists ? 1 : 0

  name        = "${local.aurora_app_name}-db-connect-migrator"
  description = "Allows IAM database authentication as tftesting_migrator. Used only to run schema migrations against the tftesting cluster."
  policy      = data.aws_iam_policy_document.db_connect_migrator[0].json
}

resource "aws_iam_role_policy_attachment" "db_connect_migrator_ci" {
  count      = local.tftesting_cluster_exists ? 1 : 0
  role       = data.aws_iam_role.ci.name
  policy_arn = aws_iam_policy.db_connect_migrator[0].arn
}
