module "cdap_cluster" {
  source                = "../../modules/cluster"
  platform              = module.platform
  cluster_name_override = "cdap-${var.env}-tftesting"
}
