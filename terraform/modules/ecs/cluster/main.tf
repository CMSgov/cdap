provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

module "platform" {
  source      = "github.com/CMSgov/cdap//terraform/modules/platform"
  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/modules/ecs"
  service     = "fargate"
  providers = { aws = aws, aws.secondary = aws.secondary }
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
