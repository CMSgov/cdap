resource "aws_ecs_cluster" "this" {
  name = var.cluster_name_override != null ? var.cluster_name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}"

  setting {
    name  = "containerInsights"
    value = var.platform.is_ephemeral_env ? "disabled" : "enabled"
  }

  configuration {
    managed_storage_configuration {
      fargate_ephemeral_storage_kms_key_id = var.platform.kms_alias_primary.target_key_arn
      kms_key_id                           = var.platform.kms_alias_primary.target_key_arn
    }
  }

  dynamic "service_connect_defaults" {
    for_each = var.enable_service_connect ? [1] : []
    content {
      namespace = aws_service_discovery_http_namespace.this[0].arn
    }
  }
}

resource "aws_service_discovery_http_namespace" "this" {
  count = var.enable_service_connect ? 1 : 0

  name        = var.cluster_name_override != null ? var.cluster_name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}"
  description = "ECS Service Connect namespace for ${var.platform.app}-${var.platform.env}-${var.platform.service}"

  tags = var.tags
}

