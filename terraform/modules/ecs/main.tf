module "platform" {
  source      = "github.com/CMSgov/cdap//terraform/modules/platform"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/modules/ecs"
  service     = "fargate"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.cluster_name}-${var.env}"

  setting {
    name  = "containerInsights"
    value = module.platform.is_ephemeral_env ? "disabled" : "enabled"
  }

  configuration {
    managed_storage_configuration {
      fargate_ephemeral_storage_kms_key_id = var.cluster_kms_master_key_id
      kms_key_id                           = var.cluster_kms_master_key_id
    }
  }
}
