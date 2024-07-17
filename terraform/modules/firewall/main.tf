locals {
  common_tags = {
    terraform = "true"
  }
  app = var.app
  env = var.env
}

//TODO: 
// - Add rate limiting rule to match BCDA's config
// - SQL Injection ruleset
// - Cloudfront distribution (?)
resource "aws_wafv2_web_acl" "this" {
  name  = "${var.app}-${var.env}-wafv2-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {

    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAF_Common_Protections"
    sampled_requests_enabled   = true
  }

  dynamic "rule" {
    for_each = var.rate_based_rule != null ? [var.rate_based_rule] : []
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            dynamic "custom_response" {
              for_each = rule.value.response_code != 403 ? [1] : []
              content {
                response_code = rule.value.response_code
              }
            }
          }
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.ip_sets_rule
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }

        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {
            dynamic "custom_response" {
              for_each = rule.value.response_code != 403 ? [1] : []
              content {
                response_code = rule.value.response_code
              }
            }
          }
        }
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.ip_set_arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "CommonRuleset"
    priority = 0
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "CommonRuleset"
        vendor_name = "AWS"

        rule_action_override {
          name = "Example"
          action_to_use {
            allow {}
          }

        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAF_Managed_Common_Ruleset"
      sampled_requests_enabled   = true
    }

  }
  tags = merge(
    local.common_tags, {
      customer = "wafv2-web-acl"
    }
  )
}

resource "aws_cloudwatch_log_group" "this" {
    name = "aws-wafv2-web-acl-logs"
    retention_in_days = 30
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.this.arn]
  resource_arn = aws_wafv2_web_acl.this.arn

  depends_on = [
    aws_wafv2_web_acl.this,
    aws_cloudwatch_log_group.this
  ]
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = var.aws_lb_arn
  web_acl_arn = aws_wafv2_web_acl.this.arn

  depends_on = [
    aws_wafv2_web_acl.this,
    aws_cloudwatch_log_group.this
  ]
}
