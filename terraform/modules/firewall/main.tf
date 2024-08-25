//TODO: 
// - Add rate limiting rule to match BCDA's config
// - SQL Injection ruleset
// - Cloudfront distribution (?)

locals {
  rate_limit_content = {
    APPLICATION_JSON = <<EOT
{
    "issue": [
        {
            "code": "throttled",
            "details": {
                "text": "Requests from this IP are currently throttled due to exceeding the limit. Try again in 5 minutes."
            },
            "severity": "error"
        }
    ],
    "resourceType": "OperationOutcome"
}
EOT
    TEXT_HTML        = <<EOT
<html>
  <p>Requests from this IP are currently throttled due to exceeding the limit. Try again in 5 minutes.</p>
</html>
EOT
    TEXT_PLAIN       = "Requests from this IP are currently throttled due to exceeding the limit. Try again in 5 minutes."
  }
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.name
  scope = var.scope

  default_action {
    allow {}
  }

  custom_response_body {
    key          = "rate-limit-exceeded"
    content      = local.rate_limit_content[var.content_type]
    content_type = var.content_type
  }

  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {
        custom_response {
          custom_response_body_key = "rate-limit-exceeded"
          response_code            = 429
          response_header {
            name  = "Retry-After"
            value = "300"
          }
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 300
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.name
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  count = var.associated_resource_arn != "" ? 1 : 0

  resource_arn = var.associated_resource_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
