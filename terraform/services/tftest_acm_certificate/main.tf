module "platform" {
  providers = { aws = aws, aws.secondary = aws.secondary }

  source      = "../../modules/platform"
  app         = "cdap"
  env         = "test"
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/acm-tests"
  service     = "tf-test-acm-certificate"
}

module "private_acm_certificate" {
  source                   = "../../modules/acm_certificate"
  platform                 = module.platform
  enable_internal_endpoint = true
  enable_zscaler_endpoint  = true
}

module "public_acm_certificate" {
  source             = "../../modules/acm_certificate"
  platform           = module.platform
  public_domain_name = "tftest-acm-certificate.cdap.cms.gov"
}

