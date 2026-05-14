# --------------------
# Execution Role IAM
#----------------------

resource "aws_iam_role" "execution" {
  count = var.execution_role_arn != null ? 0 : 1
  name  = "${local.service_name_full}-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "execution" {
  count  = var.execution_role_arn != null ? 0 : 1
  name   = "${aws_ecs_task_definition.this.family}-execution"
  role   = aws_iam_role.execution[0].name
  policy = data.aws_iam_policy_document.execution[0].json
}


data "aws_iam_policy_document" "execution" {
  count = var.execution_role_arn != null ? 0 : 1
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(data.aws_ssm_parameter.secrets) > 0 ? [1] : []
    content {
      sid    = "AllowSSMParameterAccess"
      effect = "Allow"
      actions = [
        "ssm:GetParameters",
        "ssm:GetParameter"
      ]
      resources = [for secret in data.aws_ssm_parameter.secrets : secret.arn]
    }
  }

  statement {
    sid    = "AllowDatadogSSMAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = [data.aws_ssm_parameter.datadog_api_key.arn]
  }

  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
    effect    = "Allow"
  }

  dynamic "statement" {
    for_each = var.enable_ecs_service_connect ? [1] : []
    content {
      sid       = "AllowPassServiceConnectRole"
      actions   = ["iam:PassRole"]
      resources = [aws_iam_role.service_connect[0].arn]
    }
  }
}

# -------------------------
# Service Connect Role IAM
#---------------------------

resource "aws_iam_role" "service_connect" {
  count = var.enable_ecs_service_connect ? 1 : 0
  name  = "${local.service_name_full}-service-connect"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs.amazonaws.com" }
      },
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_policy" "service_connect" {
  count       = var.enable_ecs_service_connect ? 1 : 0
  name        = "${local.service_name_full}-service-connect"
  description = "Base permissions for ECS Service Connect TLS lifecycle"
  policy      = data.aws_iam_policy_document.service_connect.json
}

resource "aws_iam_role_policy_attachment" "service_connect" {
  count      = var.enable_ecs_service_connect ? 1 : 0
  role       = aws_iam_role.service_connect[0].name
  policy_arn = aws_iam_policy.service_connect[0].arn
}

data "aws_iam_policy_document" "service_connect" {
  statement {
    sid = "AllowPCAUse"
    actions = [
      "acm-pca:GetCertificate",
      "acm-pca:GetCertificateAuthorityCertificate",
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:IssueCertificate"
    ]
    resources = data.aws_ram_resource_share.pace_ca.resource_arns
  }

  dynamic "statement" {
    for_each = var.enable_ecs_service_connect && var.service_connect_namespace != null ? [1] : []
    content {
      sid = "AllowCertManagement"
      actions = [
        "acm:ExportCertificate",
        "acm:DescribeCertificate",
        "acm:GetCertificate"
      ]
      resources = ["arn:aws:acm:${var.platform.primary_region.name}:${var.platform.account_id}:certificate/*"]

      condition {
        test     = "StringLike"
        variable = "acm:DomainName"
        values   = ["*.${var.service_connect_namespace.name}"]
      }
    }
  }

  # Scoped to ECS Service Connect-managed secrets only (ecs-sc! prefix)
  statement {
    sid = "AllowSecretsManagerForTLS"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:RotateSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.platform.primary_region.name}:${var.platform.account_id}:secret:ecs-sc!*"
    ]
  }

  statement {
    sid = "AllowKMSDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyPair"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
  }
}

# -------------------------------------------------------
# Task Role — assumed by the running container
# -------------------------------------------------------
resource "aws_iam_role" "task" {
  count = var.task_role_arn == null ? 1 : 0

  name = "${local.service_name_full}-task-role"

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
    Name = "${local.service_name_full}-task-role"
  }
}

resource "aws_iam_role_policy_attachment" "task_additional" {
  for_each = var.task_role_arn == null ? toset(var.additional_task_role_policies) : toset([])

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "task" {
  name   = "${local.service_name_full}-task-policy"
  role   = aws_iam_role.task[0].name
  policy = data.aws_iam_policy_document.task.json
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "AllowKMSDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
  }
  # -------------------------------------------------------
  # Future: RDS IAM Authentication
  # Uncomment and fill in db-cluster-resource-id when ready
  # -------------------------------------------------------
  # statement {
  #   sid     = "AllowRDSIAMAuth"
  #   actions = ["rds-db:connect"]
  #   resources = [
  #     var.database_arn
  #   ]
  # }
}
