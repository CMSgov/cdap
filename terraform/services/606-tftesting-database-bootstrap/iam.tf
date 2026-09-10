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
