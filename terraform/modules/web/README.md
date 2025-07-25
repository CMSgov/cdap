# CDAP Web Module

This module creates a CloudFront distribution and associated resources intended for use with the AB2D, BCDA and DPC static websites. This module is semi-opinionated in that it (1) provides default values where those values are currently shared across the three static websites, (2) allows for a single origin only, and (3) limits cache behaviors to a single, default set.

A sample minimal calling configuration is as follows:

```
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
    domain_name         = "example.cms.gov"
    origin_id           = "s3"
  }
}
```
