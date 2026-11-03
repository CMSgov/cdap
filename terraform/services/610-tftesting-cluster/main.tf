module "cdap_cluster" {
  source                   = "../../modules/cluster"
  platform                 = merge(module.platform, { service = "tftesting" })
  supports_service_connect = true
}
