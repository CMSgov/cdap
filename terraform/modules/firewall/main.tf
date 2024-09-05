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
    name     = "us-only"
    priority = 1

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["PR", "US", "VI"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-us-only"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "ip-sets"
    priority = 2

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          or_statement {
            dynamic "statement" {
              for_each = var.ip_sets
              iterator = ip_set
              content {
                ip_set_reference_statement {
                  arn = ip_set.value
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-ip-sets"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "aws-common"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Override for XSS block on request body, DPC team sends HTML blocks in requests to certain endpoints
        rule_action_override {
          name = "CrossSiteScripting_BODY"
          action_to_use {
            count {}
          }
        }

        # Override for size requirements of requests, this is set at 8kb which is too small for some acceptable requests
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-aws-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-ip-reputation"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-bad-inputs"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-aws-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit"
    priority = 6

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
        limit              = var.rate_limit
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
