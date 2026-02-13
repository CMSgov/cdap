locals {
  service_name      = var.service_name_override != null ? var.service_name_override : var.platform.service
  service_name_full = "${var.platform.app}-${var.platform.env}-${local.service_name}"
  container_name    = var.container_name_override != null ? var.container_name_override : var.platform.service
}

resource "random_string" "unique_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name_full
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.execution[0].arn
  task_role_arn            = var.task_role_arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions = nonsensitive(jsonencode([
    {
      name         = local.service_name_full
      image        = var.image
      portMappings = var.port_mappings
      mountPoints  = var.mount_points
      secrets      = var.container_secrets
      environment  = var.container_environment
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/fargate/${var.platform.app}-${var.platform.env}/${local.service_name}"
          awslogs-create-group  = "true"
          awslogs-region        = var.platform.primary_region.name
          awslogs-stream-prefix = "${var.platform.app}-${var.platform.env}"
        }
      }
      healthCheck = var.health_check
    }
  ]))

  dynamic "volume" {
    for_each = var.volumes != null ? toset(var.volumes) : toset([])

    content {
      name                = volume.value.name
      configure_at_launch = volume.value.configure_at_launch

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []

        content {
          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [efs_volume_configuration.value.authorization_config] : []

            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam
            }
          }

          file_system_id     = efs_volume_configuration.value.file_system_id
          root_directory     = efs_volume_configuration.value.root_directory
          transit_encryption = "ENABLED"
        }
      }
    }
  }
}

data "aws_service_discovery_http_namespace" "cluster-service_discovery-namespace" {
  name = basename(var.cluster_arn)
}

data "aws_ecs_cluster" "cluster" {
  cluster_name = var.cluster_arn
}

resource "aws_ecs_service" "this" {
  name                 = local.service_name_full
  cluster              = var.cluster_arn
  task_definition      = aws_ecs_task_definition.this.arn
  desired_count        = var.desired_count
  launch_type          = "FARGATE"
  platform_version     = "1.4.0"
  force_new_deployment = var.force_new_deployment
  propagate_tags       = "SERVICE"

  service_connect_configuration {
    enabled   = true
    namespace = data.aws_service_discovery_http_namespace.cluster-service_discovery-namespace.arn
    service {
      discovery_name = "ecs-sc-discovery-${random_string.unique_suffix.result}"
      port_name      = var.port_mappings[0].name
      client_alias {
        dns_name = local.service_name_full
        port     = var.port_mappings[0].containerPort
      }
      tls {
        kms_key  = data.aws_kms_alias.kms_key.arn
        role_arn = aws_iam_role.service-connect.arn

        issuer_cert_authority {
          aws_pca_authority_arn = one(data.aws_ram_resource_share.pace_ca.resource_arns)
        }
      }
    }
 }

  network_configuration {
    subnets          = keys(var.platform.private_subnets)
    assign_public_ip = false
    security_groups  = var.security_groups
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
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

data "aws_iam_policy_document" "service_connect_pca" {
  statement {
    sid       = "AllowDescribePCA"
    actions   = ["acm-pca:DescribeCertificateAuthority"]
    resources = [one(data.aws_ram_resource_share.pace_ca.resource_arns)]
  }

  statement {
    sid       = "AllowGetAndIssueCertificate"
    actions   = ["acm-pca:GetCertificateAuthorityCsr","acm-pca:GetCertificate", "acm-pca:IssueCertificate"]
    resources = [one(data.aws_ram_resource_share.pace_ca.resource_arns)]
  }
}

resource "aws_iam_policy" "service_connect_pca" {
  name        = "${random_string.unique_suffix.result}-service-connect-pca-policy"
  description = "Permissions for the ${var.platform.env}-${local.service_name} Service's Service Connect Role to use the PACE Private CA."
  policy      = data.aws_iam_policy_document.service_connect_pca.json
}

data "aws_iam_policy_document" "service_connect_secrets_manager" {
  statement {
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:DescribeSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DeleteSecret",
      "secretsmanager:RotateSecret",
      "secretsmanager:UpdateSecretVersionStage"
    ]
    resources = ["arn:aws:secretsmanager:${var.platform.primary_region.name}:${data.aws_caller_identity.current.account_id}:secret:ecs-sc!*"]
  }
}

resource "aws_iam_policy" "service_connect_secrets_manager" {
  name        = "${random_string.unique_suffix.result}-service-connect-secrets-manager-policy"
  description = "Permissions for the ${var.platform.env} ${local.service_name} Service's Service Connect Role to use Secrets Manager for Service Connect related Secrets."
  policy      = data.aws_iam_policy_document.service_connect_secrets_manager.json
}

data "aws_iam_policy_document" "service_assume_role" {
  for_each = toset(["ecs-tasks", "ecs"])
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["${each.value}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service-connect" {
  name                  = "${local.service_name_full}-service-connect"
  assume_role_policy    = data.aws_iam_policy_document.service_assume_role["ecs"].json
  force_detach_policies = true
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid = "AllowEnvCMKAccess"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
      "kms:GenerateDataKeyPair",
      "kms:GenerateDataKeyPairWithoutPlaintext",
    ]
    resources = [data.aws_kms_alias.kms_key.arn]
  }
}

resource "aws_iam_policy" "service_connect_kms" {
  name        = "${random_string.unique_suffix.result}-service-connect-kms-policy"
  description = "Permissions for the ${var.platform.env} ${local.service_name} Service's Service Connect Role to use the ${var.platform.env} CMK"
  policy      = data.aws_iam_policy_document.kms.json
}

resource "aws_iam_role_policy_attachment" "service-connect" {
  for_each = {
    kms             = aws_iam_policy.service_connect_kms.arn
    pca             = aws_iam_policy.service_connect_pca.arn
    secrets_manager = aws_iam_policy.service_connect_secrets_manager.arn
  }

  role       = aws_iam_role.service-connect.arn
  policy_arn = each.value
}
