data "aws_caller_identity" "this" {}

data "aws_acm_certificate" "issued" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_function" "redirects" {
  name    = "redesign-redirects"
  runtime = "cloudfront-js-2.0"
  comment = "Function that handles cool URIs and redirects."
  code    = templatefile("${path.module}/redirects-function.tftpl", { redirects = var.redirects })
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.domain_name
  description                       = "Manages an AWS CloudFront Origin Access Control, which is used by CloudFront Distributions with an Amazon S3 bucket as the origin."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${var.platform.app}-${var.platform.env}-StsHeaderPolicy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = false
      include_subdomains         = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = [var.domain_name]
  comment             = "Distribution for the ${var.platform.app}-${var.platform.env} website"
  default_root_object = "index.html"
  enabled             = var.enabled
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  web_acl_id          = var.web_acl.arn

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
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = var.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id = (
      var.platform.env == "prod" ?
      "658327ea-f89d-4fab-a63d-7e88639e58f6" : # CachingOptimized managed policy
      "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"   # CachingDisabled managed policy
    )

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer_request"
      function_arn = aws_cloudfront_function.redirects.arn
    }
  }

  origin {
    domain_name              = var.origin_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = var.s3_origin_id
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = data.aws_acm_certificate.issued.arn
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}