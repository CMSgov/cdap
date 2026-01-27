locals {
  naming_prefix = "${var.platform.app}-${var.platform.env}-${var.service}"
  caching_policy = {
    CachingDisabled  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    CachingOptimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }
}

data "aws_acm_certificate" "issued" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

# IAM
# S3 static site host bucket policy document
data "aws_iam_policy_document" "allow_cloudfront_access" {
  statement {
    sid    = "AllowCloudfrontAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.this.arn
      ]
    }

    resources = [
      module.origin_bucket.arn,
      "${module.origin_bucket.arn}/*"
    ]
  }
  statement {
    sid    = "AllowSSLRequestsOnly"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      module.origin_bucket.arn,
      "${module.origin_bucket.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = module.origin_bucket.id
  policy = data.aws_iam_policy_document.allow_cloudfront_access.json
}

data "aws_wafv2_web_acl" "this" {
  scope = "CLOUDFRONT"
  name  = "SamQuickACLEnforcingV2"
}

# Cloudfront core
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = module.origin_bucket.bucket_regional_domain_name
    origin_id                = var.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  aliases             = [var.domain_name]
  enabled             = var.enabled
  comment             = "Distribution for the ${local.naming_prefix} hosted at ${var.domain_name}"
  default_root_object = "index.html"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  web_acl_id          = data.aws_wafv2_web_acl.this.arn

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

  default_cache_behavior {
    cache_policy_id            = var.platform.env == "prod" ? local.caching_policy["CachingOptimized"] : local.caching_policy["CachingDisabled"]
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = var.s3_origin_id
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirects.arn
    }
  }

  # 403 points to a 404 page to hide information about private resources
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

  lifecycle {
    create_before_destroy = true
  }
}

# Redirect function
resource "aws_cloudfront_function" "redirects" {
  name    = "${local.naming_prefix}-redirects"
  runtime = "cloudfront-js-2.0"
  comment = "Function that handles cool URIs and redirects for ${local.naming_prefix}."
  code    = templatefile("${path.module}/redirects-function.tftpl", { redirects = var.redirects })
}

# S3 origin for distribution
module "origin_bucket" {
  source = "../bucket"
  app    = var.platform.app
  env    = var.platform.env
  name   = var.domain_name
}

# Core Cloudfront distribution
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = module.origin_bucket.id
  description                       = "Manages an AWS CloudFront Origin Access Control, which is used by CloudFront Distributions with an Amazon S3 bucket as the origin."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${local.naming_prefix}-StsHeaderPolicy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = false
      include_subdomains         = true
    }
  }
}

# WAF and firewall
resource "aws_wafv2_ip_set" "this" {
  # There is no IP blocking in Prod for the Static Site
  name               = "${local.naming_prefix}-${var.service}"
  description        = "IP set with access to ${var.domain_name}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = sensitive(var.allowed_ips_list)
}

module "firewall" {
  source       = "../firewall"
  name         = local.naming_prefix
  app          = var.platform.app
  env          = var.platform.env
  scope        = "CLOUDFRONT"
  content_type = "APPLICATION_JSON"
  ip_sets      = coalesce([aws_wafv2_ip_set.this.arn], var.existing_ip_sets)
}

# Logging

resource "aws_cloudwatch_log_delivery_source" "this" {
  name         = local.naming_prefix
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "this" {
  name          = local.naming_prefix
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = var.platform.splunk_logging_bucket.arn
  }
}

resource "aws_cloudwatch_log_delivery" "this" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.this.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.this.arn

  s3_delivery_configuration {
    suffix_path = "/AWSLogs/${var.platform.aws_caller_identity.account_id}/Cloudfront/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
  }
}
