# -------------------------------------------------------
# Additional Task Policies —
# -------------------------------------------------------
resource "aws_iam_role" "exec_access" {
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

resource "aws_iam_policy" "ecs_exec" {
  name        = "${module.platform.app}-${module.platform.env}-tftesting-ecs-exec"
  description = "Allows ECS Exec (execute-command) for interactive debugging. Test environments only."
  policy      = data.aws_iam_policy_document.ecs_exec.json
}

data "aws_iam_policy_document" "ecs_exec" {
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
}

# -------------------------------------------------------
# Legacy —
# -------------------------------------------------------
resource "aws_iam_role" "legacy_task" {
  name = "cdap-test-tftesting-legacy-task-role"

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
    Name = "cdap-test-tftesting-legacy-task-role"
  }
}


resource "aws_iam_role_policy" "legacy_task" {
  name   = "cdap-test-tftesting-legacy-task-policy"
  role   = aws_iam_role.legacy_task.name
  policy = data.aws_iam_policy_document.legacy_task.json
}

data "aws_iam_policy_document" "legacy_task" {
  statement {
    sid = "AllowKMSDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [module.platform.kms_alias_primary.target_key_arn]
  }
}
