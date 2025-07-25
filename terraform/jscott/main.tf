module "cloudfront_test" {
  source = "../modules/web"

  aws_cloudfront_origin_access_control = {
    name                              = "example"
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
  }

  enabled = false

  origin = {
    domain_name         = "test.bcda.cms.gov"
    origin_id           = "s3"
  }
}