data "aws_wafv2_web_acl" "this" {
  name  = var.aws_wafv2_web_acl.name
  scope = var.aws_wafv2_web_acl.scope
}

data "aws_acm_certificate" "this" {
  domain   = var.origin.domain_name
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.aws_cloudfront_origin_access_control.name
  description                       = var.aws_cloudfront_origin_access_control.description
  origin_access_control_origin_type = var.aws_cloudfront_origin_access_control.origin_access_control_origin_type
  signing_behavior                  = var.aws_cloudfront_origin_access_control.signing_behavior
  signing_protocol                  = var.aws_cloudfront_origin_access_control.signing_protocol
}

resource "aws_cloudfront_distribution" "this" {
  aliases             = var.aliases
  anycast_ip_list_id  = var.anycast_ip_list_id
  comment             = var.comment
  default_root_object = var.default_root_object
  enabled             = var.enabled
  http_version        = var.http_version
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  retain_on_delete    = var.retain_on_delete
  staging             = var.staging
  tags                = var.tags
  wait_for_deployment = var.wait_for_deployment
  web_acl_id          = data.aws_wafv2_web_acl.this.arn    

  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
    }
  }

  default_cache_behavior {
    allowed_methods             = var.default_cache_behavior.allowed_methods
    cached_methods              = var.default_cache_behavior.cached_methods
    cache_policy_id             = var.default_cache_behavior.cache_policy_id
    compress                    = var.default_cache_behavior.compress
    default_ttl                 = var.default_cache_behavior.default_ttl
    field_level_encryption_id   = var.default_cache_behavior.field_level_encryption_id
    max_ttl                     = var.default_cache_behavior.max_ttl
    min_ttl                     = var.default_cache_behavior.min_ttl
    origin_request_policy_id    = var.default_cache_behavior.origin_request_policy_id
    realtime_log_config_arn     = var.default_cache_behavior.realtime_log_config_arn
    response_headers_policy_id  = var.default_cache_behavior.response_headers_policy_id
    smooth_streaming            = var.default_cache_behavior.smooth_streaming
    target_origin_id            = var.origin.origin_id
    trusted_key_groups          = var.default_cache_behavior.trusted_key_groups
    trusted_signers             = var.default_cache_behavior.trusted_signers
    viewer_protocol_policy      = var.default_cache_behavior.viewer_protocol_policy
  
    dynamic function_association {
      for_each =  var.default_cache_behavior.function_association
      content {
        event_type    = function_association["event_type"]
        function_arn  = function_association["function_arn"]
      }
    }

    dynamic lambda_function_association {
      for_each = var.default_cache_behavior.lambda_function_association
      content {
        event_type    = lambda_function_association["event_type"]
        lambda_arn    = lambda_function_association["lambda_arn"]
        include_body  = lambda_function_association["include_body"]
      }
    }
  }

  dynamic logging_config {
    for_each = var.logging_config
    content {
      bucket          = var.logging_config.bucket
      include_cookies = var.logging_config.include_cookies
      prefix          = var.logging_config.prefix
    }
  }

  origin {
    connection_attempts       = var.origin.connection_attempts
    connection_timeout        = var.origin.connection_timeout
    domain_name               = var.origin.domain_name
    origin_access_control_id  = aws_cloudfront_origin_access_control.this.id
    origin_id                 = var.origin.origin_id
    origin_path               = var.origin.origin_path
  }

  restrictions {
    geo_restriction {
      restriction_type  = var.restrictions.restriction_type
      locations         = var.restrictions.locations
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.this.arn
    minimum_protocol_version = var.viewer_certificate.minimum_protocol_version
    ssl_support_method       = var.viewer_certificate.ssl_support_method
  }
}
