resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.bucket.bucket_regional_domain_name
  description                       = "Manages an AWS CloudFront Origin Access Control, which is used by CloudFront Distributions with an Amazon S3 bucket as the origin."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "viewer_request" {
  count   = length(var.viewer_request_function_list)

  code    = var.viewer_request_function_list[count.index].code
  comment = var.viewer_request_function_list[count.index].comment
  name    = var.viewer_request_function_list[count.index].name
  runtime = var.viewer_request_function_list[count.index].runtime
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = [var.certificate.domain_name]
  comment             = "Distribution for the ${var.certificate.domain_name} website"
  default_root_object = "index.html"
  enabled             = var.enabled
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
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
    allowed_methods         = ["GET", "HEAD"]
    cached_methods          = ["GET", "HEAD"]
    cache_policy_id         = var.cache_policy_id
    compress                = true
    default_ttl             = 3600
    max_ttl                 = 86400
    min_ttl                 = 0
    target_origin_id        = "s3_origin"
    viewer_protocol_policy  = "redirect-to-https"
  
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    dynamic function_association {
      for_each =  aws_cloudfront_function.viewer_request
      content {
        event_type    = "viewer_request"
        function_arn  = function_association.value.arn
      }
    }
  }

  origin {
    domain_name               = var.bucket.bucket_regional_domain_name
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
    acm_certificate_arn      = var.certificate.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}
