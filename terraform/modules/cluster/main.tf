locals {
  cluster_name = var.cluster_name_override != null ? var.cluster_name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}"
}

# CloudWatch Log Group for ECS Container Insights. If we don't manage this explicitly, it will be created automatically by AWS and we won't be able to manage the retention period via Terraform.
resource "aws_cloudwatch_log_group" "ecs_container_insights_logs" {
  name              = "/aws/ecs/containerinsights/${local.cluster_name}/performance"
  retention_in_days = 180
  kms_key_id        = var.platform.kms_alias_primary.target_key_arn

  tags = {
    Application = var.platform.app
    Environment = var.platform.env
    Service     = var.platform.service
  }
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  depends_on = [
    aws_cloudwatch_log_group.ecs_container_insights_logs
  ]

  configuration {
    managed_storage_configuration {
      fargate_ephemeral_storage_kms_key_id = var.platform.kms_alias_primary.target_key_arn
      kms_key_id                           = var.platform.kms_alias_primary.target_key_arn
    }
  }
}
