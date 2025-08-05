locals {
  domain_prefix = var.staging ? "stage.${var.app}" : "${var.app}"
}

data "aws_acm_certificate" "this" {
  domain   = "${local.domain_prefix}.cms.gov"
  statuses = ["ISSUED"]
}

data "aws_wafv2_web_acl" "this" {
  name  = "SamQuickACLEnforcingV2"
  scope = "CLOUDFRONT"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${local.domain_prefix}-s3-origin"
  description                       = "Manages an AWS CloudFront Origin Access Control, which is used by CloudFront Distributions with an Amazon S3 bucket as the origin."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = ["${data.aws_acm_certificate.this.domain}"]
  comment             = "Distribution for the ${local.domain_prefix} website"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  web_acl_id          = data.aws_wafv2_web_acl.this.arn

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
  }

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    allowed_methods             = ["GET", "HEAD"]
    cached_methods              = ["GET", "HEAD"]
    cache_policy_id             = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress                    = true
    default_ttl                 = 3600
    max_ttl                     = 86400
    min_ttl                     = 0
    target_origin_id            = "s3_origin"
    viewer_protocol_policy      = "redirect-to-https"
  
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name               = "${var.origin_s3_bucket_name}.s3.us-east-1.amazonaws.com"
    origin_access_control_id  = aws_cloudfront_origin_access_control.this.id
    origin_id                 = "s3_origin"
  }

  restrictions {
    geo_restriction {
      restriction_type  = "whitelist"
      locations         = ["US"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.this.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}
