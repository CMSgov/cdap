data "aws_iam_policy" "rds_monitoring" {
  name = "AmazonRDSEnhancedMonitoringRole"
}

data "aws_iam_policy" "developer_boundary_policy" {
  name = "developer-boundary-policy"
}

data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

# Role allowing Enhanced Monitoring for this cluster's instances. Always
# created and managed by this module -- teams no longer supply their own.
resource "aws_iam_role" "db_monitoring" {
  name                 = "${local.service_prefix}-rds-monitoring"
  assume_role_policy   = data.aws_iam_policy_document.rds_monitoring_assume.json
  path                 = var.monitoring_role_path
  permissions_boundary = data.aws_iam_policy.developer_boundary_policy.arn
}

resource "aws_iam_role_policy_attachment" "db_monitoring" {
  role       = aws_iam_role.db_monitoring.name
  policy_arn = data.aws_iam_policy.rds_monitoring.arn
}

# Scoped to exactly the KMS key this cluster uses for storage encryption /
# Performance Insights -- not a broader, separately-managed policy.
data "aws_iam_policy_document" "db_monitoring_kms" {
  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [coalesce(var.kms_key_override, var.platform.kms_alias_primary.target_key_arn)]
  }
}

resource "aws_iam_policy" "db_monitoring_kms" {
  name   = "${local.service_prefix}-rds-monitoring-kms"
  policy = data.aws_iam_policy_document.db_monitoring_kms.json
}

resource "aws_iam_role_policy_attachment" "db_monitoring_kms" {
  role       = aws_iam_role.db_monitoring.name
  policy_arn = aws_iam_policy.db_monitoring_kms.arn
}
