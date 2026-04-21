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
    sid = "AllowSSMRead"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${module.platform.primary_region.name}:${module.platform.aws_caller_identity}:/cdap/test/tftesting/*"
    ]
  }

  statement {
    sid = "AllowACMRead"
    actions = [
      "acm:ExportCertificate",
      "acm:DescribeCertificate",
      "acm:GetCertificate"
    ]
    resources = [
      "arn:aws:acm:${module.platform.primary_region.name}:${module.platform.aws_caller_identity}:certificate/*"
    ]
  }

  statement {
    sid = "AllowECRAuthToken"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowCloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${module.platform.primary_region.name}:${module.platform.aws_caller_identity}:log-group:/aws/ecs/fargate/cdap-test/*"
    ]
  }
}

