module "cdap_cluster" {
  source                = "../../modules/cluster"
  platform              = module.platform
  cluster_name_override = "cdap-${var.env}-tftesting"
}

resource "aws_service_discovery_http_namespace" "test" {
  name        = "cdap-${var.env}.cmscloud.local"
  description = "Service Connect namespace for ECS module testing"
}
