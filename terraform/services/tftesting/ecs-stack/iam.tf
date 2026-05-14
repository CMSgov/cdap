# -------------------------------------------------------
# Task Role — assumed by the running container
# -------------------------------------------------------
resource "aws_iam_role" "task" {
  name = "cdap-test-tftesting-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })

  tags = {
    Name = "cdap-test-tftesting-task-role"
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "cdap-test-tftesting-task-policy"
  role   = aws_iam_role.task.name
  policy = data.aws_iam_policy_document.task.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "AllowKMSDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [module.platform.kms_alias_primary.target_key_arn]
  }

  statement {
    sid = "AllowECSExec"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
  # -------------------------------------------------------
  # Future: RDS IAM Authentication
  # Uncomment and fill in db-cluster-resource-id when ready
  # -------------------------------------------------------
  # statement {
  #   sid     = "AllowRDSIAMAuth"
  #   actions = ["rds-db:connect"]
  #   resources = [
  #     "arn:aws:rds-db:${var.region}:${var.account_id}:dbuser:${var.db_resource_id}/${var.db_user}"
  #   ]
  # }
}
