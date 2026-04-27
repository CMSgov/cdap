# --------------------------------
# Task Role IAM handled externally
#---------------------------------

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
      "logs:PutLogEvents",
      "ssm:GetParameters"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "kms:Decrypt"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
    effect    = "Allow"
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
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
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

  statement {
    sid = "AllowCertManagement"
    actions = [
      "acm:ExportCertificate",
      "acm:DescribeCertificate",
      "acm:GetCertificate"
    ]
    resources = ["arn:aws:acm:${var.platform.primary_region.name}:${var.platform.account_id}:certificate/*"]
  }

  statement {
    sid = "AllowKMSDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [var.platform.kms_alias_primary.target_key_arn]
  }
}
