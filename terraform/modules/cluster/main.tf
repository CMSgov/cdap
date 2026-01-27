resource "aws_ecs_cluster" "this" {
  name = var.cluster_name_override != null ? var.cluster_name_override : "${var.platform.app}-${var.platform.env}-${var.platform.service}"

  setting {
    name  = "containerInsights"
    value = var.platform.is_ephemeral_env ? "disabled" : "enabled"
  }

  service_connect_defaults {
    namespace = "arn:aws:servicediscovery:us-east-1:539247469933:namespace/ns-fsnhpeorze262a2c"
  }

  configuration {
    managed_storage_configuration {
      fargate_ephemeral_storage_kms_key_id = var.platform.kms_alias_primary.target_key_arn
      kms_key_id                           = var.platform.kms_alias_primary.target_key_arn
    }
  }
}
